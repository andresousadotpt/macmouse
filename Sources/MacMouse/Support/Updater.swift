import AppKit
import MacMouseCore
import Security

/// Downloads a release archive, checks it is signed by the same certificate as
/// the running copy, swaps it in place and relaunches.
enum Updater {
    enum Failure: LocalizedError {
        case notInstallable
        case missingApp
        case untrusted
        case wrongVersion(String)
        case unzip

        var errorDescription: String? {
            switch self {
            case .notInstallable: "This copy can't update itself. Download the new version instead."
            case .missingApp: "The download did not contain the app."
            case .untrusted: "The download is not signed by the MacMouse release certificate."
            case .wrongVersion(let found): "The download contains version \(found), not the expected one."
            case .unzip: "Could not unpack the download."
            }
        }
    }

    /// `owner/repo` to check for releases; `nil` under `swift run` and for local
    /// "Dev" builds, which must not offer to replace themselves with a release.
    static var repository: String? {
        guard Bundle.main.bundleIdentifier?.hasSuffix(".dev") == false else { return nil }
        return AppInfo.repository
    }

    static var bundleURL: URL { Bundle.main.bundleURL }

    /// Self-install needs a certificate-signed bundle (ad-hoc builds have no stable
    /// identity to check the download against) in a folder we can write to.
    static var canInstall: Bool {
        guard bundleURL.pathExtension == "app", ownRequirement() != nil else { return false }
        let fm = FileManager.default
        return fm.isWritableFile(atPath: bundleURL.path)
            && fm.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
    }

    static func install(_ release: AppRelease) async throws {
        guard canInstall, let requirement = ownRequirement() else { throw Failure.notInstallable }
        let fm = FileManager.default
        // Same volume as the app, so the final swap is a rename.
        let staging = try fm.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: bundleURL, create: true
        )
        defer { try? fm.removeItem(at: staging) }

        let (download, _) = try await URLSession.shared.download(from: release.downloadURL)
        let archive = staging.appendingPathComponent("update.zip")
        try fm.moveItem(at: download, to: archive)

        let unpacked = staging.appendingPathComponent("unpacked", isDirectory: true)
        try await run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])
        guard let newApp = try fm.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" })
        else { throw Failure.missingApp }

        try verify(newApp, requirement: requirement, version: release.version)
        _ = try fm.replaceItemAt(bundleURL, withItemAt: newApp)
        relaunch()
    }

    // MARK: Signature

    private static func ownRequirement() -> SecRequirement? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode
        else { return nil }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info
        ) == errSecSuccess,
            let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [Any],
            !certificates.isEmpty
        else { return nil } // ad-hoc: the requirement would pin this exact build

        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess else { return nil }
        return requirement
    }

    private static func verify(_ app: URL, requirement: SecRequirement, version: SemanticVersion) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else {
            throw Failure.untrusted
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else {
            throw Failure.untrusted
        }
        let found = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        guard SemanticVersion(found) == version else { throw Failure.wrongVersion(found) }
    }

    // MARK: Helpers

    private static func run(_ tool: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Failure.unzip)
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    /// Only one instance may run, so a helper waits for us to exit before reopening.
    private static func relaunch() {
        let script = "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\""
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "relaunch", "\(ProcessInfo.processInfo.processIdentifier)", bundleURL.path]
        try? helper.run()
        Task { @MainActor in NSApp.terminate(nil) }
    }
}
