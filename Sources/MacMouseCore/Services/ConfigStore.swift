import Foundation

/// Loads and saves `MouseConfig` as JSON with atomic writes.
public actor ConfigStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MacMouse", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    /// Returns the saved config, or defaults when none exists or it is unreadable.
    public func load() -> MouseConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(MouseConfig.self, from: data)
        else { return .defaults }
        return config
    }

    public func save(_ config: MouseConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
