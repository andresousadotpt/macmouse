import AppKit
import MacMouseCore
import SwiftUI

/// Bundle facts shown in About; `packaging/build-app.sh` writes `MacMouseRepository`.
enum AppInfo {
    static var repository: String? {
        Bundle.main.object(forInfoDictionaryKey: "MacMouseRepository") as? String
    }

    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "MacMouse"
    }

    static var copyright: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }

    static var versionText: String {
        guard let build = AppVersion.build else { return "Version \(AppVersion.marketing)" }
        return "Version \(AppVersion.marketing) (\(build))"
    }

    static func gitHubURL(_ path: String = "") -> URL? {
        guard let repository else { return nil }
        return URL(string: "https://github.com/\(repository)\(path)")
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text(AppInfo.name).font(.title.bold())
                Text(AppInfo.versionText)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Smooth scrolling and button remapping for third-party mice.")
                .multilineTextAlignment(.center)
            if AppInfo.repository != nil {
                HStack(spacing: 16) {
                    link("GitHub", "")
                    link("Release Notes", "/releases")
                    link("Report an Issue", "/issues/new/choose")
                }
            }
            Spacer()
            VStack(spacing: 2) {
                if let copyright = AppInfo.copyright {
                    Text(copyright)
                }
                Text("Everything runs on this Mac; the only network access is the optional update check.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding([.horizontal, .bottom], 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func link(_ title: String, _ path: String) -> some View {
        if let url = AppInfo.gitHubURL(path) {
            Link(title, destination: url)
        }
    }
}
