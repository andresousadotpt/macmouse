import CoreGraphics
import Foundation
import MacMouseCore

/// Creates and posts synthetic input events. Every event is tagged so our own
/// event tap recognizes and ignores it.
@MainActor
enum EventPoster {
    /// Written to `eventSourceUserData` on every event we post.
    nonisolated static let tag: Int64 = 0x4D41_434D_4F55 // "MACMOU"

    private static let source = CGEventSource(stateID: .privateState)

    nonisolated static func isOwn(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == tag
    }

    /// Posts with explicit modifier flags. Events created from a source inherit the
    /// modifiers it remembers, so after a ⌘[ keystroke (Back) a later synthetic scroll
    /// could arrive as ⌘-scroll and zoom instead.
    private static func post(_ event: CGEvent?, flags: CGEventFlags = []) {
        guard let event else { return }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        event.post(tap: .cghidEventTap)
    }

    static func pressKey(_ keyCode: UInt16, flags: CGEventFlags) {
        for isDown in [true, false] {
            post(CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown), flags: flags)
        }
    }

    static func perform(_ route: ActionRoute) {
        switch route {
        case .systemHotKey(let hotKey):
            SymbolicHotKeys.trigger(hotKey)
        case .keystroke(let keyCode, let modifiers):
            pressKey(keyCode, flags: CGEventFlags(rawValue: modifiers.rawValue))
        case .middleClick:
            click(button: 3)
        case .smartZoom:
            postGesture(subtype: 22)
        }
    }

    /// Posts a plain down/up pair for a 1-based button number (3 = middle).
    static func click(button: Int) {
        let location = CGEvent(source: nil)?.location ?? .zero
        // Keep the modifiers physically held, so ⌘-middle-click still opens a background tab.
        let held = CGEventFlags(rawValue: ModifierSet(
            eventFlags: CGEventSource.flagsState(.hidSystemState).rawValue
        ).rawValue)
        let number = Int64(button - 1)
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            let event = CGEvent(
                mouseEventSource: source, mouseType: type,
                mouseCursorPosition: location, mouseButton: .center
            )
            event?.setIntegerValueField(.mouseEventButtonNumber, value: number)
            event?.setIntegerValueField(.mouseEventClickState, value: 1)
            post(event, flags: held)
        }
    }

    enum Phase: Int64 {
        case none = 0, began = 1, changed = 2, ended = 4
    }

    // Trackpad gestures are window-server events of type 29 with no public
    // constructor. Field numbers are listed in docs/CLEAN_ROOM.md.
    private static let gestureSubtype = CGEventField(rawValue: 110)!
    private static let gestureScrollX = CGEventField(rawValue: 116)!
    private static let gestureScrollY = CGEventField(rawValue: 119)!
    private static let gestureMagnification = CGEventField(rawValue: 113)!
    private static let gesturePhase = CGEventField(rawValue: 132)!

    private static func postGesture(subtype: Int64, phase: Phase = .none, configure: (CGEvent) -> Void = { _ in }) {
        guard let event = CGEvent(source: source) else { return }
        event.type = unsafeBitCast(UInt32(29), to: CGEventType.self)
        event.setIntegerValueField(gestureSubtype, value: subtype)
        if phase != .none {
            event.setIntegerValueField(gesturePhase, value: phase.rawValue)
        }
        configure(event)
        post(event)
    }

    /// Posts a trackpad-style pinch step.
    static func magnify(_ amount: Double, phase: Phase) {
        postGesture(subtype: 8, phase: phase) {
            $0.setDoubleValueField(gestureMagnification, value: amount)
        }
    }

    /// Posts a pixel-precise ("continuous") scroll, like a trackpad would.
    /// Positive `dy` scrolls content down (wheel up), positive `dx` scrolls left.
    static func scroll(dx: Int32, dy: Int32, phase: Phase = .none) {
        let event = CGEvent(
            scrollWheelEvent2Source: source, units: .pixel,
            wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0
        )
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        if phase != .none {
            event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase.rawValue)
        }
        post(event)
        // A trackpad pairs each phased scroll with a scroll gesture, which apps use
        // for trackpad-only behaviour such as elastic overscroll.
        if phase != .none {
            postGesture(subtype: 6, phase: phase) {
                $0.setDoubleValueField(gestureScrollX, value: Double(dx))
                $0.setDoubleValueField(gestureScrollY, value: Double(dy))
            }
        }
    }
}
