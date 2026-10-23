import CoreGraphics
import Foundation
import MacMouseCore

/// Triggers macOS system shortcuts (Mission Control, Spaces, …) by pressing
/// whatever key combination the user has bound to them. If an action has no
/// binding or is disabled, a temporary binding is installed, pressed, and the
/// original state restored shortly after.
///
/// The window server functions used here are not in the public SDK, so they
/// are resolved at runtime; if unavailable, triggering silently does nothing.
@MainActor
enum SymbolicHotKeys {
    private typealias GetValue = @convention(c) (
        Int32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt32>
    ) -> Int32
    private typealias SetValue = @convention(c) (Int32, UInt16, UInt16, UInt32) -> Int32
    private typealias IsEnabled = @convention(c) (Int32) -> Bool
    private typealias SetEnabled = @convention(c) (Int32, Bool) -> Int32

    private struct API {
        let getValue: GetValue
        let setValue: SetValue
        let isEnabled: IsEnabled
        let setEnabled: SetEnabled
    }

    private static let api: API? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let get = dlsym(handle, "CGSGetSymbolicHotKeyValue"),
              let set = dlsym(handle, "CGSSetSymbolicHotKeyValue"),
              let isOn = dlsym(handle, "CGSIsSymbolicHotKeyEnabled"),
              let setOn = dlsym(handle, "CGSSetSymbolicHotKeyEnabled")
        else { return nil }
        return API(
            getValue: unsafeBitCast(get, to: GetValue.self),
            setValue: unsafeBitCast(set, to: SetValue.self),
            isEnabled: unsafeBitCast(isOn, to: IsEnabled.self),
            setEnabled: unsafeBitCast(setOn, to: SetEnabled.self)
        )
    }()

    private static let unboundKeyCode: UInt16 = 0xFFFF
    /// Unlikely to collide with anything: ⌃⌥⇧⌘F19.
    private static let fallbackModifiers = UInt32(ModifierSet.all.rawValue)

    static func trigger(_ hotKey: SystemHotKey) {
        guard let api else { return }
        let id = hotKey.rawValue
        var character: UInt16 = 0
        var keyCode: UInt16 = 0
        var modifiers: UInt32 = 0
        let readOK = api.getValue(id, &character, &keyCode, &modifiers) == 0
        let wasEnabled = api.isEnabled(id)

        if readOK && wasEnabled && keyCode != unboundKeyCode {
            EventPoster.pressKey(keyCode, flags: CGEventFlags(rawValue: UInt64(modifiers)))
            return
        }

        _ = api.setValue(id, unboundKeyCode, KeyCode.f19, fallbackModifiers)
        _ = api.setEnabled(id, true)
        EventPoster.pressKey(KeyCode.f19, flags: CGEventFlags(rawValue: UInt64(fallbackModifiers)))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if readOK {
                _ = api.setValue(id, character, keyCode, modifiers)
            }
            _ = api.setEnabled(id, wasEnabled)
        }
    }
}
