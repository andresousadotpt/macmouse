import Foundation

/// How a wheel event should be handled, given the held keyboard modifiers.
public struct ScrollMode: Equatable, Sendable {
    public var horizontal = false
    public var precise = false
    public var fast = false
    /// Each notch zooms in or out instead of scrolling.
    public var zoom = false
    /// A modifier the user did not assign to us is held: leave the event to
    /// the system (only the reverse-direction setting is still applied).
    public var passThrough = false

    public init(horizontal: Bool = false, precise: Bool = false, fast: Bool = false, zoom: Bool = false, passThrough: Bool = false) {
        self.horizontal = horizontal
        self.precise = precise
        self.fast = fast
        self.zoom = zoom
        self.passThrough = passThrough
    }

    public static let fastMultiplier = 3.0
    public static let precisePixelsPerNotch = 8.0
}

public extension ScrollSettings {
    func mode(for held: ModifierSet) -> ScrollMode {
        var mode = ScrollMode()
        var claimed: ModifierSet = []
        func check(_ key: ModifierKey) -> Bool {
            guard key != .none, held.contains(key.set) else { return false }
            claimed.insert(key.set)
            return true
        }
        mode.horizontal = check(horizontalModifier)
        mode.precise = check(preciseModifier)
        mode.fast = check(fastModifier)
        mode.zoom = check(zoomModifier)
        mode.passThrough = !held.subtracting(claimed).isEmpty
        return mode
    }
}
