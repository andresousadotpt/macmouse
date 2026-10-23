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
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit MacMouse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
