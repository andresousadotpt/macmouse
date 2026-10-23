import Foundation

/// Keyboard modifiers, using the same bit layout as macOS event flags so the
/// app layer can convert without a lookup table.
public struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    public static let shift = ModifierSet(rawValue: 1 << 17)
    public static let control = ModifierSet(rawValue: 1 << 18)
    public static let option = ModifierSet(rawValue: 1 << 19)
    public static let command = ModifierSet(rawValue: 1 << 20)

    public static let all: ModifierSet = [.shift, .control, .option, .command]

    /// Keeps only the four modifiers above, dropping device-dependent bits.
    public init(eventFlags: UInt64) {
        self.init(rawValue: eventFlags & ModifierSet.all.rawValue)
    }

    public var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// A single modifier key the user can assign to a scroll mode.
public enum ModifierKey: String, Codable, CaseIterable, Sendable {
    case none, shift, control, option, command

    public var set: ModifierSet {
        switch self {
        case .none: []
        case .shift: .shift
        case .control: .control
        case .option: .option
        case .command: .command
        }
    }

    public var title: String {
        switch self {
        case .none: "None"
        case .shift: "⇧ Shift"
        case .control: "⌃ Control"
        case .option: "⌥ Option"
        case .command: "⌘ Command"
        }
    }
}

public struct KeyShortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: ModifierSet
    /// Human-readable key label captured when the shortcut was recorded.
    public var keyLabel: String

    public init(keyCode: UInt16, modifiers: ModifierSet, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public var displayString: String { modifiers.symbols + keyLabel }
}

public enum MouseAction: Codable, Hashable, Sendable {
    case missionControl
    case appWindows
    case showDesktop
    case launchpad
    case spaceLeft
    case spaceRight
    case back
    case forward
    case middleClick
    case lookUp
    case zoomIn
    case zoomOut
    case smartZoom
    case shortcut(KeyShortcut)

    /// Actions offered in pickers (custom shortcuts are added via the recorder).
    public static let presets: [MouseAction] = [
        .missionControl, .appWindows, .showDesktop, .launchpad,
        .spaceLeft, .spaceRight, .back, .forward, .middleClick,
        .lookUp, .zoomIn, .zoomOut, .smartZoom,
    ]

    public var title: String {
        switch self {
        case .missionControl: "Mission Control"
        case .appWindows: "Application Windows"
        case .showDesktop: "Show Desktop"
        case .launchpad: "Launchpad"
        case .spaceLeft: "Move Left a Space"
        case .spaceRight: "Move Right a Space"
        case .back: "Back"
        case .forward: "Forward"
        case .middleClick: "Middle Click"
        case .lookUp: "Look Up"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .smartZoom: "Smart Zoom"
        case .shortcut(let s): "Shortcut \(s.displayString)"
        }
    }
}

public struct ButtonTrigger: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case click, hold
    }

    public var kind: Kind
    /// 1 = single, 2 = double, 3 = triple.
    public var clicks: Int

    public init(_ kind: Kind, clicks: Int = 1) {
        self.kind = kind
        self.clicks = min(max(clicks, 1), ButtonTrigger.maxClicks)
    }

    public static let maxClicks = 3

    public var title: String {
        let prefix = ["", "Double ", "Triple "][clicks - 1]
        switch kind {
        case .click: return clicks == 1 ? "Click" : prefix + "Click"
        case .hold: return clicks == 1 ? "Hold" : prefix + "Click and Hold"
        }
    }
}

public struct ButtonMapping: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// 1-based button number as users know it: 3 = middle, 4 = back, 5 = forward.
    public var button: Int
    public var trigger: ButtonTrigger
    public var action: MouseAction

    public init(id: UUID = UUID(), button: Int, trigger: ButtonTrigger, action: MouseAction) {
        self.id = id
        self.button = button
        self.trigger = trigger
        self.action = action
    }
}

/// What happens when the mouse moves while a button is held.
public enum DragBehavior: String, Codable, CaseIterable, Sendable {
    case none
    /// Up: Mission Control, down: Application Windows, left/right: Spaces.
    case gestures
    /// Grab-and-pan the content under the pointer.
    case scroll

    public var title: String {
        switch self {
        case .none: "Nothing"
        case .gestures: "Spaces & Mission Control"
        case .scroll: "Grab and Scroll"
        }
    }
}

/// What happens when the wheel turns while a button is held.
public enum WheelBehavior: String, Codable, CaseIterable, Sendable {
    case none, zoom, horizontalScroll, spaces

    public var title: String {
        switch self {
        case .none: "Nothing"
        case .zoom: "Zoom In or Out"
        case .horizontalScroll: "Horizontal Scroll"
        case .spaces: "Move Between Spaces"
        }
    }
}

public struct ButtonHoldBehavior: Codable, Hashable, Sendable {
    public var drag: DragBehavior
    public var wheel: WheelBehavior

    public init(drag: DragBehavior = .none, wheel: WheelBehavior = .none) {
        self.drag = drag
        self.wheel = wheel
    }

    public var isEmpty: Bool { drag == .none && wheel == .none }
}

public enum Smoothness: String, Codable, CaseIterable, Sendable {
    case off, regular, high

    public var title: String { rawValue.capitalized }
}

public enum ScrollSpeed: String, Codable, CaseIterable, Sendable {
    case slow, medium, fast

    public var title: String { rawValue.capitalized }
}

public struct ScrollSettings: Codable, Hashable, Sendable {
    public var smoothness: Smoothness = .high
    public var speed: ScrollSpeed = .medium
    public var reverseDirection = false
    public var horizontalModifier: ModifierKey = .shift
    public var preciseModifier: ModifierKey = .option
    public var fastModifier: ModifierKey = .control
    public var zoomModifier: ModifierKey = .command

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case smoothness, speed, reverseDirection
        case horizontalModifier, preciseModifier, fastModifier, zoomModifier
    }

    // Missing keys fall back to defaults, so configs saved before a setting existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ScrollSettings()
        smoothness = try c.decodeIfPresent(Smoothness.self, forKey: .smoothness) ?? d.smoothness
        speed = try c.decodeIfPresent(ScrollSpeed.self, forKey: .speed) ?? d.speed
        reverseDirection = try c.decodeIfPresent(Bool.self, forKey: .reverseDirection) ?? d.reverseDirection
        horizontalModifier = try c.decodeIfPresent(ModifierKey.self, forKey: .horizontalModifier) ?? d.horizontalModifier
        preciseModifier = try c.decodeIfPresent(ModifierKey.self, forKey: .preciseModifier) ?? d.preciseModifier
        fastModifier = try c.decodeIfPresent(ModifierKey.self, forKey: .fastModifier) ?? d.fastModifier
        zoomModifier = try c.decodeIfPresent(ModifierKey.self, forKey: .zoomModifier) ?? d.zoomModifier
    }
}

public struct UpdateSettings: Codable, Hashable, Sendable {
    public var checkAutomatically = true
    /// Download, install and relaunch without asking. Off: only show a notice.
    public var installAutomatically = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case checkAutomatically, installAutomatically
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UpdateSettings()
        checkAutomatically = try c.decodeIfPresent(Bool.self, forKey: .checkAutomatically) ?? d.checkAutomatically
        installAutomatically = try c.decodeIfPresent(Bool.self, forKey: .installAutomatically) ?? d.installAutomatically
    }
}

public struct MouseConfig: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version = MouseConfig.currentVersion
    public var enabled = true
    public var scroll = ScrollSettings()
    public var mappings: [ButtonMapping] = []
    /// Keyed by 1-based button number.
    public var holdBehaviors: [Int: ButtonHoldBehavior] = [:]
    public var updates = UpdateSettings()

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, enabled, scroll, mappings, holdBehaviors, updates
    }

    // Missing keys fall back to defaults, so configs saved by older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MouseConfig()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        scroll = try c.decodeIfPresent(ScrollSettings.self, forKey: .scroll) ?? d.scroll
        mappings = try c.decodeIfPresent([ButtonMapping].self, forKey: .mappings) ?? d.mappings
        holdBehaviors = try c.decodeIfPresent([Int: ButtonHoldBehavior].self, forKey: .holdBehaviors) ?? d.holdBehaviors
        updates = try c.decodeIfPresent(UpdateSettings.self, forKey: .updates) ?? d.updates
    }

    /// Defaults for a typical five-button mouse.
    public static var defaults: MouseConfig {
        var config = MouseConfig()
        config.mappings = [
            ButtonMapping(button: 4, trigger: ButtonTrigger(.click), action: .back),
            ButtonMapping(button: 5, trigger: ButtonTrigger(.click), action: .forward),
            ButtonMapping(button: 3, trigger: ButtonTrigger(.click, clicks: 2), action: .missionControl),
        ]
        config.holdBehaviors = [
            4: ButtonHoldBehavior(drag: .gestures),
            5: ButtonHoldBehavior(wheel: .zoom),
        ]
        return config
    }

    public func triggers(for button: Int) -> Set<ButtonTrigger> {
        Set(mappings.filter { $0.button == button }.map(\.trigger))
    }

    public func action(for button: Int, trigger: ButtonTrigger) -> MouseAction? {
        mappings.first { $0.button == button && $0.trigger == trigger }?.action
    }

    public func holdBehavior(for button: Int) -> ButtonHoldBehavior {
        holdBehaviors[button] ?? ButtonHoldBehavior()
    }

    /// Primary and secondary buttons are never intercepted (R10); any other
    /// button is intercepted only when the user configured something for it (R15).
    public func intercepts(button: Int) -> Bool {
        guard button >= 3 else { return false }
        return !triggers(for: button).isEmpty || !holdBehavior(for: button).isEmpty
    }
}
