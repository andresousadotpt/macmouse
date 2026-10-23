import Foundation

public enum AppVersion {
    /// `CFBundleShortVersionString` from `packaging/Info.plist` (the version source
    /// of truth); "dev" when running outside an app bundle (`swift run`, tests).
    public static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
