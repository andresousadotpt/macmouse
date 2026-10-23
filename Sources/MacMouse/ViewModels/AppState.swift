import AppKit
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
    private(set) var update: UpdateStatus = .idle

    enum UpdateStatus: Equatable {
        case idle, checking, upToDate, installing
        case available(AppRelease)
        case failed(String)
    }

    var availableUpdate: AppRelease? {
        if case .available(let release) = update { return release }
        return nil
    }

    /// `false` for development builds without a repository or a stable signature.
    let canCheckForUpdates = Updater.repository != nil
    let canInstallUpdates = Updater.canInstall

    @ObservationIgnored private let engine = MouseEngine()
    @ObservationIgnored private let store = ConfigStore(fileURL: ConfigStore.defaultURL)
    @ObservationIgnored private var permissionTimer: Timer?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var updateTimer: Timer?
    @ObservationIgnored private var lastCheck: Date?
    /// The version the update alert was last shown for, so it appears once per release.
    @ObservationIgnored private var alertedVersion: SemanticVersion?

    private static let checkInterval: TimeInterval = 6 * 60 * 60

    init() {
        Task {
            let saved = await store.load()
            isLoaded = true
            config = saved
            engine.config = saved
            if !Accessibility.isTrusted { Accessibility.requestAccess() }
            refreshPermission()
            checkForUpdates(userInitiated: false)
        }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForUpdates(userInitiated: false) }
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
        let updates = config.updates
        config = .defaults
        config.updates = updates
    }

    // MARK: Updates

    func checkForUpdates(userInitiated: Bool) {
        guard let repository = Updater.repository, update != .checking, update != .installing else { return }
        if !userInitiated {
            guard config.updates.checkAutomatically else { return }
            if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.checkInterval { return }
        }
        lastCheck = Date()
        update = .checking
        let feed = ReleaseFeed(repository: repository, bundleName: Updater.bundleURL.deletingPathExtension().lastPathComponent)
        Task {
            do {
                guard let release = try await feed.latest(), release.isNewer(than: AppVersion.marketing) else {
                    update = .upToDate
                    return
                }
                update = .available(release)
                if config.updates.installAutomatically && canInstallUpdates {
                    installUpdate()
                } else if userInitiated || alertedVersion != release.version {
                    alertedVersion = release.version
                    showUpdateAlert(release)
                }
            } catch {
                update = userInitiated ? .failed("Could not check for updates: \(error.localizedDescription)") : .idle
            }
        }
    }

    func installUpdate() {
        guard let release = availableUpdate else { return }
        guard canInstallUpdates else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        update = .installing
        Task {
            do {
                try await Updater.install(release)
            } catch {
                update = .failed(error.localizedDescription)
            }
        }
    }

    private func showUpdateAlert(_ release: AppRelease) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MacMouse \(release.version) is available"
        alert.informativeText = "You have version \(AppVersion.marketing)."
            + (canInstallUpdates ? "" : " This copy can't update itself, so the download page will open.")
        alert.addButton(withTitle: canInstallUpdates ? "Install and Relaunch" : "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Release Notes")
        switch alert.runModal() {
        case .alertFirstButtonReturn: installUpdate()
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.pageURL)
        default: break
        }
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
