import Foundation

/// Asks GitHub for the latest published release of the app.
public struct ReleaseFeed: Sendable {
    /// `owner/repo` on GitHub.
    public let repository: String
    /// Archive prefix, i.e. `APP_BUNDLE_NAME` (`macmouse` → `macmouse-1.2.3.zip`).
    public let bundleName: String

    public init(repository: String, bundleName: String) {
        self.repository = repository
        self.bundleName = bundleName
    }

    public func latest() async throws -> AppRelease? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(bundleName)/\(AppVersion.marketing)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try AppRelease.fromGitHub(data, bundleName: bundleName)
    }
}
