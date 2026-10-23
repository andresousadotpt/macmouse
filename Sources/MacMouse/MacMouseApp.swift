import AppKit
import MacMouseCore
import SwiftUI

@main
struct MacMouseApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra("MacMouse", systemImage: "computermouse") {
            MenuContent(state: state)
        }
        Settings {
            SettingsView(state: state)
        }
    }
}

private struct MenuContent: View {
    @Bindable var state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("MacMouse — \(state.statusText)")
        if !state.isTrusted {
            Button("Grant Accessibility Access…") {
                Accessibility.requestAccess()
                Accessibility.openSettings()
            }
        }
        Toggle("Enabled", isOn: $state.config.enabled)
        Divider()
        Button("Settings…") {
            openSettings()
            // A menu-bar-only app is never frontmost, so the window would open behind others.
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.windows
                    .first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }?
                    .makeKeyAndOrderFront(nil)
            }
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit MacMouse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
