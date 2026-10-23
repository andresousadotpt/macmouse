import Foundation

/// Identifiers of macOS "symbolic hot keys" — the system-wide shortcuts listed
/// under System Settings › Keyboard › Keyboard Shortcuts. These IDs are the
/// keys of `com.apple.symbolichotkeys` › `AppleSymbolicHotKeys`.
public enum SystemHotKey: Int32, Sendable {
    case missionControl = 32
    case appWindows = 33
    case showDesktop = 36
    case spaceLeft = 79
    case spaceRight = 81
    case launchpad = 160
}

/// How an action is delivered to the system.
public enum ActionRoute: Equatable, Sendable {
    case systemHotKey(SystemHotKey)
    case keystroke(keyCode: UInt16, modifiers: ModifierSet)
    case middleClick
}

/// macOS virtual key codes (US layout positions) for the keys we press.
public enum KeyCode {
    public static let d: UInt16 = 0x02
    public static let equal: UInt16 = 0x18
    public static let minus: UInt16 = 0x1B
    public static let rightBracket: UInt16 = 0x1E
    public static let leftBracket: UInt16 = 0x21
    public static let f19: UInt16 = 0x50
}

public extension MouseAction {
    var route: ActionRoute {
        switch self {
        case .missionControl: .systemHotKey(.missionControl)
        case .appWindows: .systemHotKey(.appWindows)
        case .showDesktop: .systemHotKey(.showDesktop)
        case .launchpad: .systemHotKey(.launchpad)
        case .spaceLeft: .systemHotKey(.spaceLeft)
        case .spaceRight: .systemHotKey(.spaceRight)
        case .back: .keystroke(keyCode: KeyCode.leftBracket, modifiers: .command)
        case .forward: .keystroke(keyCode: KeyCode.rightBracket, modifiers: .command)
        case .middleClick: .middleClick
        case .lookUp: .keystroke(keyCode: KeyCode.d, modifiers: [.control, .command])
        case .zoomIn: .keystroke(keyCode: KeyCode.equal, modifiers: .command)
        case .zoomOut: .keystroke(keyCode: KeyCode.minus, modifiers: .command)
        case .shortcut(let s): .keystroke(keyCode: s.keyCode, modifiers: s.modifiers)
        }
    }
}
