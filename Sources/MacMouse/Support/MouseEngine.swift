import AppKit
import CoreGraphics
import MacMouseCore
import QuartzCore

/// Owns the event tap and turns raw mouse input into MacMouse behaviour.
/// Everything runs on the main thread: the tap's run-loop source is attached
/// to the main run loop, and animation is driven by a display link.
@MainActor
final class MouseEngine: NSObject {
    var config = MouseConfig() {
        didSet { configDidChange() }
    }

    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?

    // Buttons
    private var clicks = ClickRecognizer()
    private var clickTimer: DispatchWorkItem?
    private var heldButton: Int?
    /// The held button acted as a modifier (drag or wheel), so it must not click.
    private var heldButtonWasUsed = false
    private var activeDrag: DragBehavior = .none
    private var dragTravel = 0.0
    private var dragDirection = DragDirectionRecognizer()
    private var panPhase: EventPoster.Phase = .began
    private var lastSpaceSwitch: TimeInterval = 0

    // Scrolling
    private var animator = ScrollAnimator(tuning: .init(speed: .medium, smoothness: .high))
    private var displayLink: CADisplayLink?
    private var lastFrame: TimeInterval?
    private var glidePhase: EventPoster.Phase = .began

    private static let dragStartDistance = 6.0
    private static let spaceSwitchCooldown: TimeInterval = 0.45

    // MARK: Lifecycle

    /// Installs the event tap. Fails when Accessibility access is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mouseEngineTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
        isRunning = true
        return true
    }

    func stop() {
        resetInteraction()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        tap = nil
        tapSource = nil
        isRunning = false
    }

    private func configDidChange() {
        animator.tuning = .init(speed: config.scroll.speed, smoothness: config.scroll.smoothness)
        if !config.enabled { resetInteraction() }
    }

    private func resetInteraction() {
        endDrag()
        clicks.cancel()
        clickTimer?.cancel()
        heldButton = nil
        animator.stop()
        displayLink?.isPaused = true
    }

    // MARK: Event dispatch

    /// Returns `true` to let the event continue to apps, `false` to swallow it.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        }
        guard config.enabled, !EventPoster.isOwn(event) else { return true }
        let now = ProcessInfo.processInfo.systemUptime
        switch type {
        case .otherMouseDown: return buttonDown(event, at: now)
        case .otherMouseUp: return buttonUp(event, at: now)
        case .otherMouseDragged: return mouseDragged(event)
        case .scrollWheel: return scrollWheel(event, at: now)
        default: return true
        }
    }

    private static func buttonNumber(_ event: CGEvent) -> Int {
        Int(event.getIntegerValueField(.mouseEventButtonNumber)) + 1
    }

    // MARK: Buttons

    private func buttonDown(_ event: CGEvent, at now: TimeInterval) -> Bool {
        let button = Self.buttonNumber(event)
        guard config.intercepts(button: button) else { return true }
        // Chords of two intercepted buttons are not supported; let the second through.
        if let heldButton, heldButton != button { return true }

        heldButton = button
        heldButtonWasUsed = false
        dragTravel = 0
        dragDirection.reset()
        perform(clicks.buttonDown(button, at: now, triggers: config.triggers(for: button)))
        scheduleClickTimer(now: now)
        return false
    }

    private func buttonUp(_ event: CGEvent, at now: TimeInterval) -> Bool {
        let button = Self.buttonNumber(event)
        guard button == heldButton else { return true }
        heldButton = nil
        endDrag()
        if heldButtonWasUsed {
            clicks.cancel()
        } else {
            perform(clicks.buttonUp(button, at: now))
        }
        scheduleClickTimer(now: now)
        return false
    }

    private func perform(_ outputs: [ClickRecognizer.Output]) {
        for output in outputs {
            switch output {
            case .fire(let button, let trigger):
                if let action = config.action(for: button, trigger: trigger) {
                    EventPoster.perform(action.route)
                }
            case .replayClick(let button):
                EventPoster.click(button: button)
            }
        }
    }

    private func scheduleClickTimer(now: TimeInterval) {
        clickTimer?.cancel()
        guard let deadline = clicks.nextDeadline else { return }
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.clickTimerFired() }
        }
        clickTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline - now), execute: item)
    }

    private func clickTimerFired() {
        let now = ProcessInfo.processInfo.systemUptime
        perform(clicks.tick(at: now))
        scheduleClickTimer(now: now)
    }

    // MARK: Drag

    private func mouseDragged(_ event: CGEvent) -> Bool {
        guard let heldButton, Self.buttonNumber(event) == heldButton else { return true }
        let behavior = config.holdBehavior(for: heldButton).drag
        guard behavior != .none else { return true }

        let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
        let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
        if activeDrag == .none {
            dragTravel += hypot(dx, dy)
            guard dragTravel >= Self.dragStartDistance else { return true }
            beginDrag(behavior)
        }

        switch activeDrag {
        case .gestures:
            if let direction = dragDirection.add(dx: dx, dy: dy) {
                EventPoster.perform(direction.gestureAction.route)
            }
        case .scroll:
            // Grab semantics: content follows the pointer.
            EventPoster.scroll(dx: Int32(dx), dy: Int32(dy), phase: panPhase)
            panPhase = .changed
        case .none:
            break
        }
        return false
    }

    private func beginDrag(_ behavior: DragBehavior) {
        clicks.cancel()
        clickTimer?.cancel()
        heldButtonWasUsed = true
        activeDrag = behavior
        panPhase = .began
        // Freeze the pointer while still receiving movement deltas.
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    private func endDrag() {
        guard activeDrag != .none else { return }
        if activeDrag == .scroll && panPhase == .changed {
            EventPoster.scroll(dx: 0, dy: 0, phase: .ended)
        }
        activeDrag = .none
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    // MARK: Scrolling

    private func scrollWheel(_ event: CGEvent, at now: TimeInterval) -> Bool {
        // Trackpads and Magic Mouse already scroll smoothly (R5).
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return true }
        // One event is one notch; macOS's own line acceleration is replaced by ours.
        let dy = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1).signum())
        let dx = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2).signum())
        guard dx != 0 || dy != 0 else { return true }

        if let heldButton {
            let wheel = config.holdBehavior(for: heldButton).wheel
            if wheel != .none {
                heldButtonWasUsed = true
                clicks.cancel()
                clickTimer?.cancel()
                wheelWhileHeld(wheel, dx: dx, dy: dy, at: now)
                return false
            }
        }

        let settings = config.scroll
        let mode = settings.mode(for: ModifierSet(eventFlags: event.flags.rawValue))
        if mode.passThrough { return true }

        var (x, y) = (dx, dy)
        if settings.reverseDirection { (x, y) = (-x, -y) }
        if mode.horizontal && x == 0 { (x, y) = (y, 0) }

        if mode.precise {
            let step = ScrollMode.precisePixelsPerNotch
            EventPoster.scroll(dx: Int32(x * step), dy: Int32(y * step))
            return false
        }

        let multiplier = mode.fast ? ScrollMode.fastMultiplier : 1
        if settings.smoothness == .off {
            let unchanged = !settings.reverseDirection && !mode.horizontal && !mode.fast
            if unchanged { return true }
            let step = animator.tuning.pixelsPerNotch * multiplier
            EventPoster.scroll(dx: Int32(x * step), dy: Int32(y * step))
            return false
        }

        animator.addNotches(dx: x, dy: y, at: now, multiplier: multiplier)
        startGlide()
        return false
    }

    private func wheelWhileHeld(_ wheel: WheelBehavior, dx: Double, dy: Double, at now: TimeInterval) {
        let amount = dy != 0 ? dy : dx
        switch wheel {
        case .zoom:
            EventPoster.perform((amount > 0 ? MouseAction.zoomIn : .zoomOut).route)
        case .spaces:
            guard now - lastSpaceSwitch >= Self.spaceSwitchCooldown else { return }
            lastSpaceSwitch = now
            EventPoster.perform((amount > 0 ? MouseAction.spaceLeft : .spaceRight).route)
        case .horizontalScroll:
            animator.addNotches(dx: amount, dy: 0, at: now)
            startGlide()
        case .none:
            break
        }
    }

    // MARK: Glide animation

    private func startGlide() {
        if displayLink == nil {
            guard let screen = NSScreen.main else { return }
            let link = screen.displayLink(target: self, selector: #selector(frame(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        if displayLink?.isPaused ?? true || lastFrame == nil {
            lastFrame = ProcessInfo.processInfo.systemUptime
            glidePhase = .began
        }
        displayLink?.isPaused = false
    }

    @objc private func frame(_ link: CADisplayLink) {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - (lastFrame ?? now), 0.05)
        lastFrame = now

        let delta = animator.step(dt: dt)
        if delta.dx != 0 || delta.dy != 0 {
            EventPoster.scroll(dx: Int32(delta.dx), dy: Int32(delta.dy), phase: glidePhase)
            glidePhase = .changed
        }
        if animator.isIdle {
            if glidePhase == .changed {
                EventPoster.scroll(dx: 0, dy: 0, phase: .ended)
            }
            link.isPaused = true
            lastFrame = nil
        }
    }
}

/// C callback for the event tap; `refcon` is the owning `MouseEngine`.
private func mouseEngineTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return .passUnretained(event) }
    let engine = Unmanaged<MouseEngine>.fromOpaque(refcon).takeUnretainedValue()
    nonisolated(unsafe) let event = event
    // The tap source lives on the main run loop, so we are on the main thread.
    let passThrough = MainActor.assumeIsolated { engine.handle(type: type, event: event) }
    return passThrough ? .passUnretained(event) : nil
}
