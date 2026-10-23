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
        if let release = state.availableUpdate {
            Button("⚠︎ Update to \(release.version.description) Available…") { state.installUpdate() }
        }
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
            SettingsWindow.bringToFront()
        }
        .keyboardShortcut(",")
        if state.canCheckForUpdates {
            Button("Check for Updates…") { state.checkForUpdates(userInitiated: true) }
        }
        Divider()
        Button("Quit MacMouse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// MacMouse is menu-bar-only (no Dock icon, not in ⌘-Tab). While Settings is
/// open it behaves like a regular app so it can be focused and switched to.
@MainActor
enum SettingsWindow {
    static func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            window?.makeKeyAndOrderFront(nil)
        }
    }

    static func didClose() {
        NSApp.setActivationPolicy(.accessory)
    }

    private static var window: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }
    }
}
