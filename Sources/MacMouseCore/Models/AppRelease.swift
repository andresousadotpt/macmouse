import Foundation

/// A dotted numeric version such as `0.1.3`; a leading "v" is ignored.
public struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init?(_ string: String) {
        let trimmed = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        components = parts.compactMap { $0 }
    }

    public var description: String { components.map(String.init).joined(separator: ".") }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let l = i < lhs.components.count ? lhs.components[i] : 0
            let r = i < rhs.components.count ? rhs.components[i] : 0
            if l != r { return l < r }
        }
        return false
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        var trimmed = components
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }
}

/// A published release that carries a downloadable app archive.
public struct AppRelease: Equatable, Sendable {
    public var version: SemanticVersion
    public var notes: String
    public var pageURL: URL
    public var downloadURL: URL

    public init(version: SemanticVersion, notes: String, pageURL: URL, downloadURL: URL) {
        self.version = version
        self.notes = notes
        self.pageURL = pageURL
        self.downloadURL = downloadURL
    }

    public func isNewer(than current: String) -> Bool {
        guard let current = SemanticVersion(current) else { return false }
        return version > current
    }

    /// Reads a GitHub "latest release" response. Returns `nil` for drafts,
    /// pre-releases, unparseable tags, or releases without `{bundleName}-{version}.zip`.
    public static func fromGitHub(_ data: Data, bundleName: String) throws -> AppRelease? {
        struct Payload: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: URL
            }
            let tag_name: String
            let html_url: URL
            let body: String?
            let draft: Bool?
            let prerelease: Bool?
            let assets: [Asset]
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.draft != true, payload.prerelease != true,
              let version = SemanticVersion(payload.tag_name)
        else { return nil }
        let archive = "\(bundleName)-\(version).zip"
        guard let asset = payload.assets.first(where: { $0.name == archive }) else { return nil }
        return AppRelease(
            version: version, notes: payload.body ?? "",
            pageURL: payload.html_url, downloadURL: asset.browser_download_url
        )
    }
}
