import Foundation

public enum DragDirection: Equatable, Sendable {
    case up, down, left, right
}

/// Accumulates pointer movement while a button is held and reports the
/// dominant direction once the travel passes a threshold. Reports at most once
/// per drag; call `reset()` when the button is released.
public struct DragDirectionRecognizer: Sendable {
    public var threshold: Double

    private var total = (x: 0.0, y: 0.0)
    public private(set) var recognized: DragDirection?

    public init(threshold: Double = 60) {
        self.threshold = threshold
    }

    /// `dy` follows screen coordinates: positive is downward.
    public mutating func add(dx: Double, dy: Double) -> DragDirection? {
        guard recognized == nil else { return nil }
        total.x += dx
        total.y += dy
        guard hypot(total.x, total.y) >= threshold else { return nil }
        let direction: DragDirection = abs(total.x) > abs(total.y)
            ? (total.x > 0 ? .right : .left)
            : (total.y > 0 ? .down : .up)
        recognized = direction
        return direction
    }

    public mutating func reset() {
        total = (0, 0)
        recognized = nil
    }
}

public extension DragDirection {
    /// Mapping used by `DragBehavior.gestures`. Moving right reveals the Space
    /// to the left, like dragging content, matching a three-finger swipe.
    var gestureAction: MouseAction {
        switch self {
        case .up: .missionControl
        case .down: .appWindows
        case .left: .spaceRight
        case .right: .spaceLeft
        }
    }
}
