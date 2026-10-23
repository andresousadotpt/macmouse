import AppKit
import MacMouseCore
import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            GeneralTab(state: state)
                .tabItem { Label("General", systemImage: "gearshape") }
            ScrollTab(scroll: $state.config.scroll)
                .tabItem { Label("Scrolling", systemImage: "scroll") }
            ButtonsTab(config: $state.config)
                .tabItem { Label("Buttons", systemImage: "computermouse") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 620, height: 480)
        .onAppear { SettingsWindow.bringToFront() }
        .onDisappear { SettingsWindow.didClose() }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section {
                Toggle("Enable MacMouse", isOn: $state.config.enabled)
                Toggle("Launch at login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
            }
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    if state.isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open System Settings…") {
                            Accessibility.requestAccess()
                            Accessibility.openSettings()
                        }
                    }
                }
                Text("MacMouse needs Accessibility access to read and change mouse input. Everything stays on this Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let error = state.lastError {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
            if state.canCheckForUpdates {
                UpdatesSection(state: state)
            }
            Section {
                Button("Restore Default Settings") { state.restoreDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct UpdatesSection: View {
    @Bindable var state: AppState

    var body: some View {
        Section {
            Toggle("Check for updates automatically", isOn: $state.config.updates.checkAutomatically)
            Toggle("Install updates automatically", isOn: $state.config.updates.installAutomatically)
                .disabled(!state.canInstallUpdates || !state.config.updates.checkAutomatically)
            LabeledContent {
                switch state.update {
                case .available(let release):
                    Button(state.canInstallUpdates ? "Install \(release.version.description)" : "Download \(release.version.description)") {
                        state.installUpdate()
                    }
                case .checking, .installing:
                    ProgressView().controlSize(.small)
                default:
                    Button("Check Now") { state.checkForUpdates(userInitiated: true) }
                }
            } label: {
                Text(statusText)
                    .foregroundStyle(statusColor)
            }
        } header: {
            Text("Updates")
        } footer: {
            if !state.canInstallUpdates {
                Text("This copy isn't signed for self-updating, so new versions open the download page instead.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch state.update {
        case .idle: "Not checked yet"
        case .checking: "Checking…"
        case .upToDate: "MacMouse is up to date"
        case .installing: "Installing update…"
        case .available(let release): "⚠︎ Version \(release.version.description) is available"
        case .failed(let message): message
        }
    }

    private var statusColor: Color {
        switch state.update {
        case .available: .orange
        case .failed: .red
        default: .secondary
        }
    }
}

// MARK: - Scrolling

private struct ScrollTab: View {
    @Binding var scroll: ScrollSettings

    var body: some View {
        Form {
            Section {
                Picker("Smoothness", selection: $scroll.smoothness) {
                    ForEach(Smoothness.allCases, id: \.self) { Text($0.title) }
                }
                Picker("Speed", selection: $scroll.speed) {
                    ForEach(ScrollSpeed.allCases, id: \.self) { Text($0.title) }
                }
                .pickerStyle(.segmented)
                Toggle("Reverse direction", isOn: $scroll.reverseDirection)
            } footer: {
                Text("Applies to mouse wheels only. Trackpads and Magic Mouse are left untouched.")
                    .foregroundStyle(.secondary)
            }
            Section {
                modifierPicker("Horizontal scroll", $scroll.horizontalModifier)
                modifierPicker("Precise scroll", $scroll.preciseModifier)
                modifierPicker("Fast scroll", $scroll.fastModifier)
                modifierPicker("Zoom", $scroll.zoomModifier)
            } header: {
                Text("Hold a key while scrolling")
            } footer: {
                Text("Zoom works like a trackpad pinch. Other modifiers pass through to the app.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func modifierPicker(_ title: String, _ binding: Binding<ModifierKey>) -> some View {
        Picker(title, selection: binding) {
            ForEach(ModifierKey.allCases, id: \.self) { Text($0.title) }
        }
    }
}

// MARK: - Buttons

private let buttonNumbers = Array(3...8)

private func buttonName(_ number: Int) -> String {
    number == 3 ? "Middle Button" : "Button \(number)"
}

private let triggerChoices: [ButtonTrigger] = [
    ButtonTrigger(.click, clicks: 1),
    ButtonTrigger(.click, clicks: 2),
    ButtonTrigger(.click, clicks: 3),
    ButtonTrigger(.hold, clicks: 1),
    ButtonTrigger(.hold, clicks: 2),
]

private struct ButtonsTab: View {
    @Binding var config: MouseConfig

    var body: some View {
        Form {
            Section {
                ForEach($config.mappings) { $mapping in
                    MappingRow(mapping: $mapping) {
                        config.mappings.removeAll { $0.id == mapping.id }
                    }
                }
                Button {
                    config.mappings.append(
                        ButtonMapping(button: 3, trigger: ButtonTrigger(.click), action: .missionControl)
                    )
                } label: {
                    Label("Add Action", systemImage: "plus")
                }
            } header: {
                Text("Click actions")
            } footer: {
                Text("Primary and secondary buttons are never changed. Buttons without actions work as usual.")
                    .foregroundStyle(.secondary)
            }

            Section("While holding a button") {
                ForEach(buttonNumbers, id: \.self) { number in
                    HoldRow(name: buttonName(number), behavior: holdBinding(number))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func holdBinding(_ button: Int) -> Binding<ButtonHoldBehavior> {
        Binding(
            get: { config.holdBehavior(for: button) },
            set: { config.holdBehaviors[button] = $0.isEmpty ? nil : $0 }
        )
    }
}

private struct MappingRow: View {
    @Binding var mapping: ButtonMapping
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Picker("", selection: $mapping.trigger) {
                ForEach(triggerChoices, id: \.self) { Text($0.title) }
            }
            .labelsHidden()
            .frame(width: 170)
            Picker("", selection: $mapping.button) {
                ForEach(buttonNumbers, id: \.self) { Text(buttonName($0)) }
            }
            .labelsHidden()
            .frame(width: 130)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            ActionPicker(action: $mapping.action)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
    }
}

private struct ActionPicker: View {
    @Binding var action: MouseAction
    @State private var isRecording = false

    var body: some View {
        HStack {
            Picker("", selection: $action) {
                ForEach(MouseAction.presets, id: \.self) { Text($0.title).tag($0) }
                if case .shortcut = action {
                    Divider()
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            Button {
                isRecording = true
            } label: {
                Image(systemName: "keyboard")
            }
            .buttonStyle(.borderless)
            .help("Record a keyboard shortcut")
            .popover(isPresented: $isRecording) {
                ShortcutRecorder { shortcut in
                    if let shortcut { action = .shortcut(shortcut) }
                    isRecording = false
                }
            }
        }
    }
}

private struct HoldRow: View {
    let name: String
    @Binding var behavior: ButtonHoldBehavior

    var body: some View {
        LabeledContent(name) {
            HStack {
                Picker("Drag", selection: $behavior.drag) {
                    ForEach(DragBehavior.allCases, id: \.self) { Text($0.title) }
                }
                Picker("Scroll", selection: $behavior.wheel) {
                    ForEach(WheelBehavior.allCases, id: \.self) { Text($0.title) }
                }
            }
        }
    }
}
