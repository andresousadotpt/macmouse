import Foundation
import MacMouseCore
import Observation
import ServiceManagement

/// Single source of truth for the UI; forwards config changes to the engine
/// and persists them.
@MainActor
@Observable
final class AppState {
    var config = MouseConfig.defaults {
        didSet {
            guard config != oldValue else { return }
            engine.config = config
            save()
        }
    }

    private(set) var isTrusted = Accessibility.isTrusted
    private(set) var isRunning = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var lastError: String?

    @ObservationIgnored private let engine = MouseEngine()
    @ObservationIgnored private let store = ConfigStore(fileURL: ConfigStore.defaultURL)
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var isLoaded = false

    init() {
        Task {
            let saved = await store.load()
            isLoaded = true
            config = saved
            engine.config = saved
            if !Accessibility.isTrusted { Accessibility.requestAccess() }
            refreshPermission()
        }
        // Accessibility can be granted or revoked at any time in System Settings (R2).
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
    }

    var statusText: String {
        if !isTrusted { return "Needs Accessibility access" }
        if !isRunning { return "Could not start" }
        return config.enabled ? "Active" : "Paused"
    }

    func refreshPermission() {
        isTrusted = Accessibility.isTrusted
        if isTrusted && !engine.isRunning {
            engine.start()
        } else if !isTrusted && engine.isRunning {
            engine.stop()
        }
        isRunning = engine.isRunning
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = "Launch at login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func restoreDefaults() {
        config = .defaults
    }

    private func save() {
        guard isLoaded else { return }
        let snapshot = config
        Task {
            do {
                try await store.save(snapshot)
            } catch {
                lastError = "Could not save settings: \(error.localizedDescription)"
            }
        }
    }
}
