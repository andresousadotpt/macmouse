import AppKit
import MacMouseCore
import SwiftUI

/// Captures the next key press (with modifiers) as a `KeyShortcut`.
/// Escape cancels; `onFinish(nil)` is called on cancel.
struct ShortcutRecorder: View {
    let onFinish: (KeyShortcut?) -> Void
    @State private var monitor: Any?

    private static let escapeKeyCode: UInt16 = 0x35

    var body: some View {
        VStack(spacing: 8) {
            Text("Type a keyboard shortcut")
                .font(.headline)
            Text("Press Esc to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear(perform: install)
        .onDisappear(perform: remove)
    }

    private func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == Self.escapeKeyCode {
                onFinish(nil)
                return nil
            }
            let modifiers = ModifierSet(eventFlags: UInt64(event.modifierFlags.rawValue))
            let label = event.charactersIgnoringModifiers?.uppercased() ?? ""
            onFinish(KeyShortcut(
                keyCode: event.keyCode,
                modifiers: modifiers,
                keyLabel: label.isEmpty ? "Key \(event.keyCode)" : label
            ))
            return nil
        }
    }

    private func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
