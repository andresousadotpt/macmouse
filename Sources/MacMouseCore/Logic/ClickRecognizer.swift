import Foundation

/// Turns raw button down/up events into click, multi-click and hold triggers.
///
/// Pure state machine: callers supply timestamps and call `tick(at:)` once
/// `nextDeadline` has passed. A single click fires immediately unless a
/// higher-count trigger is configured for the same button, in which case it
/// waits up to `multiClickInterval` for the next press.
public struct ClickRecognizer: Sendable {
    public enum Output: Equatable, Sendable {
        /// A configured trigger was recognized.
        case fire(button: Int, trigger: ButtonTrigger)
        /// The press matched nothing; the caller should replay a plain click.
        case replayClick(button: Int)
    }

    public var multiClickInterval: TimeInterval
    public var holdDelay: TimeInterval

    private var button: Int?
    private var triggers: Set<ButtonTrigger> = []
    private var clicks = 0
    private var isDown = false
    private var holdFired = false
    private var lastUp: TimeInterval = 0
    public private(set) var nextDeadline: TimeInterval?

    public init(multiClickInterval: TimeInterval = 0.28, holdDelay: TimeInterval = 0.35) {
        self.multiClickInterval = multiClickInterval
        self.holdDelay = holdDelay
    }

    public var isIdle: Bool { button == nil }

    public mutating func buttonDown(_ pressed: Int, at time: TimeInterval, triggers: Set<ButtonTrigger>) -> [Output] {
        var output: [Output] = []
        let continuesCycle = button == pressed && !isDown && !holdFired
            && time - lastUp <= multiClickInterval && clicks < ButtonTrigger.maxClicks
        if !continuesCycle {
            // A different button (or a stale cycle) interrupts: settle it first.
            output += settlePendingClick()
            reset()
            button = pressed
        }
        self.triggers = triggers
        clicks += 1
        isDown = true
        nextDeadline = triggers.contains(ButtonTrigger(.hold, clicks: clicks)) ? time + holdDelay : nil
        return output
    }

    public mutating func buttonUp(_ released: Int, at time: TimeInterval) -> [Output] {
        guard released == button, isDown else { return [] }
        isDown = false
        lastUp = time
        nextDeadline = nil
        if holdFired {
            reset()
            return []
        }
        if hasHigherCountTrigger {
            nextDeadline = time + multiClickInterval
            return []
        }
        let output = settlePendingClick()
        reset()
        return output
    }

    public mutating func tick(at time: TimeInterval) -> [Output] {
        guard let deadline = nextDeadline, time >= deadline, let current = button else { return [] }
        nextDeadline = nil
        if isDown {
            holdFired = true
            return [.fire(button: current, trigger: ButtonTrigger(.hold, clicks: clicks))]
        }
        let output = settlePendingClick()
        reset()
        return output
    }

    /// Abandons the current cycle without emitting anything — used when the
    /// held button turns into a drag or wheel modifier.
    public mutating func cancel() {
        reset()
    }

    private var hasHigherCountTrigger: Bool {
        triggers.contains { $0.clicks > clicks }
    }

    private func settlePendingClick() -> [Output] {
        guard let current = button, !isDown, !holdFired, clicks > 0 else { return [] }
        let click = ButtonTrigger(.click, clicks: clicks)
        if triggers.contains(click) {
            return [.fire(button: current, trigger: click)]
        }
        return [.replayClick(button: current)]
    }

    private mutating func reset() {
        button = nil
        triggers = []
        clicks = 0
        isDown = false
        holdFired = false
        nextDeadline = nil
    }
}
