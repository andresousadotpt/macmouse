import Foundation

public enum AppVersion {
    /// `CFBundleShortVersionString` from `packaging/Info.plist` (the version source
    /// of truth); "dev" when running outside an app bundle (`swift run`, tests).
    public static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// `CFBundleVersion`, or `nil` outside an app bundle.
    public static var build: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
