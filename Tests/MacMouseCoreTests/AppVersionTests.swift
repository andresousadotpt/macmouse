import XCTest
@testable import MacMouseCore

final class AppVersionTests: XCTestCase {
    func testMarketingVersionIsNonEmpty() {
        XCTAssertFalse(AppVersion.marketing.isEmpty)
    }
}
