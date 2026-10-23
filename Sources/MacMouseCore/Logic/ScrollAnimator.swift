import Foundation

/// Converts discrete wheel notches into a smooth stream of pixel deltas.
///
/// Each notch adds distance to a "remaining" budget per axis. Every frame emits
/// a fixed fraction of what is left (exponential decay), so motion starts fast
/// and glides to a stop. Rapid notches in the same direction grow the distance
/// per notch, which makes long scrolls cheap. Sub-pixel remainders are carried
/// so the total emitted always equals the total requested.
public struct ScrollAnimator: Sendable {
    public struct Tuning: Equatable, Sendable {
        /// Pixels per notch before acceleration.
        public var pixelsPerNotch: Double
        /// Decay time constant in seconds; larger glides longer.
        public var timeConstant: TimeInterval
        /// Notches closer together than this count as a flick.
        public var flickInterval: TimeInterval = 0.07
        /// Extra distance per consecutive flick notch, as a fraction.
        public var flickGain: Double = 0.3
        public var maxMultiplier: Double = 5

        public init(pixelsPerNotch: Double, timeConstant: TimeInterval) {
            self.pixelsPerNotch = pixelsPerNotch
            self.timeConstant = timeConstant
        }

        public init(speed: ScrollSpeed, smoothness: Smoothness) {
            let pixels: Double = switch speed {
            case .slow: 40
            case .medium: 64
            case .fast: 100
            }
            let tau: TimeInterval = switch smoothness {
            case .off: 0
            case .regular: 0.06
            case .high: 0.11
            }
            self.init(pixelsPerNotch: pixels, timeConstant: tau)
        }
    }

    public var tuning: Tuning

    private var remaining = (x: 0.0, y: 0.0)
    private var carry = (x: 0.0, y: 0.0)
    private var lastNotch: TimeInterval = -.infinity
    private var lastDirection = (x: 0, y: 0)
    private var streak = 0

    public init(tuning: Tuning) {
        self.tuning = tuning
    }

    public var isIdle: Bool {
        remaining.x == 0 && remaining.y == 0
    }

    /// Multiplier currently applied to new notches (exposed for tests).
    public var currentMultiplier: Double {
        min(1 + Double(streak) * tuning.flickGain, tuning.maxMultiplier)
    }

    /// Registers wheel notches. Signs follow the wheel: positive `dy` scrolls up.
    public mutating func addNotches(dx: Double, dy: Double, at time: TimeInterval, multiplier: Double = 1) {
        let direction = (x: dx.signum, y: dy.signum)
        let sameDirection = direction == lastDirection
        if sameDirection && time - lastNotch <= tuning.flickInterval {
            streak += 1
        } else {
            streak = 0
        }
        // Reversing must feel immediate: drop the old glide on that axis only, so
        // mixing vertical and horizontal notches never cancels the other axis.
        if direction.x != 0 && remaining.x.signum == -direction.x {
            remaining.x = 0
            carry.x = 0
        }
        if direction.y != 0 && remaining.y.signum == -direction.y {
            remaining.y = 0
            carry.y = 0
        }
        lastNotch = time
        lastDirection = direction

        let scale = tuning.pixelsPerNotch * currentMultiplier * multiplier
        remaining.x += dx * scale
        remaining.y += dy * scale
    }

    /// Advances the animation by `dt` seconds; returns whole pixels to post.
    public mutating func step(dt: TimeInterval) -> (dx: Int, dy: Int) {
        let fraction = tuning.timeConstant > 0 ? 1 - exp(-dt / tuning.timeConstant) : 1
        let x = advance(&remaining.x, &carry.x, fraction: fraction)
        let y = advance(&remaining.y, &carry.y, fraction: fraction)
        return (x, y)
    }

    public mutating func stop() {
        remaining = (0, 0)
        carry = (0, 0)
        streak = 0
    }

    private func advance(_ remaining: inout Double, _ carry: inout Double, fraction: Double) -> Int {
        guard remaining != 0 else { return 0 }
        var move = remaining * fraction
        // Finish once the tail would be imperceptible.
        if abs(remaining - move) < 0.5 { move = remaining }
        remaining -= move
        let total = move + carry
        let whole = total.rounded(.towardZero)
        carry = total - whole
        if remaining == 0 {
            // Flush the sub-pixel carry so nothing is lost at the end.
            let flushed = whole + carry.rounded()
            carry = 0
            return Int(flushed)
        }
        return Int(whole)
    }
}

private extension Double {
    var signum: Int { self > 0 ? 1 : (self < 0 ? -1 : 0) }
}
