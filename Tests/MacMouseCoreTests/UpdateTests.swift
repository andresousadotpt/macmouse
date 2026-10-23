import XCTest
@testable import MacMouseCore

final class UpdateTests: XCTestCase {
    func testVersionOrdering() throws {
        let v = { (s: String) in try XCTUnwrap(SemanticVersion(s)) }
        XCTAssertLessThan(try v("0.1.3"), try v("0.1.4"))
        XCTAssertLessThan(try v("0.9.9"), try v("0.10.0"))
        XCTAssertEqual(try v("v1.2"), try v("1.2.0"))
        XCTAssertNil(SemanticVersion("dev"))
        XCTAssertNil(SemanticVersion("1.2.x"))
    }

    func testParsesGitHubRelease() throws {
        let json = """
        {"tag_name": "v0.2.0", "html_url": "https://github.com/o/r/releases/tag/v0.2.0",
         "body": "Notes", "draft": false, "prerelease": false,
         "assets": [{"name": "macmouse-0.2.0.zip",
                     "browser_download_url": "https://github.com/o/r/releases/download/v0.2.0/macmouse-0.2.0.zip"}]}
        """
        let release = try XCTUnwrap(AppRelease.fromGitHub(Data(json.utf8), bundleName: "macmouse"))
        XCTAssertEqual(release.version.description, "0.2.0")
        XCTAssertEqual(release.downloadURL.lastPathComponent, "macmouse-0.2.0.zip")
        XCTAssertTrue(release.isNewer(than: "0.1.9"))
        XCTAssertFalse(release.isNewer(than: "0.2.0"))
        XCTAssertFalse(release.isNewer(than: "dev"))
    }

    func testIgnoresReleasesWithoutArchiveOrPrerelease() throws {
        let noAsset = #"{"tag_name": "v1.0.0", "html_url": "https://x.y", "assets": []}"#
        XCTAssertNil(try AppRelease.fromGitHub(Data(noAsset.utf8), bundleName: "macmouse"))
        let pre = #"{"tag_name": "v1.0.0", "html_url": "https://x.y", "prerelease": true, "assets": "#
            + #"[{"name": "macmouse-1.0.0.zip", "browser_download_url": "https://x.y/a.zip"}]}"#
        XCTAssertNil(try AppRelease.fromGitHub(Data(pre.utf8), bundleName: "macmouse"))
    }

    func testOlderConfigWithoutUpdatesDecodes() throws {
        let json = #"{"enabled": false, "mappings": [], "holdBehaviors": {}, "scroll": {}, "version": 1}"#
        let config = try JSONDecoder().decode(MouseConfig.self, from: Data(json.utf8))
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.updates, UpdateSettings())
        XCTAssertFalse(config.updates.installAutomatically)
    }
}
