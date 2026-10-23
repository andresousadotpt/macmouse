import XCTest
@testable import MacMouseCore

final class ClickRecognizerTests: XCTestCase {
    private let click1 = ButtonTrigger(.click, clicks: 1)
    private let click2 = ButtonTrigger(.click, clicks: 2)
    private let hold1 = ButtonTrigger(.hold, clicks: 1)

    private func makeRecognizer() -> ClickRecognizer {
        ClickRecognizer(multiClickInterval: 0.3, holdDelay: 0.4)
    }

    func testSingleClickFiresImmediatelyWithoutHigherTriggers() {
        var r = makeRecognizer()
        XCTAssertEqual(r.buttonDown(4, at: 0, triggers: [click1]), [])
        XCTAssertEqual(r.buttonUp(4, at: 0.1), [.fire(button: 4, trigger: click1)])
        XCTAssertNil(r.nextDeadline)
        XCTAssertTrue(r.isIdle)
    }

    func testSingleClickWaitsWhenDoubleClickConfigured() {
        var r = makeRecognizer()
        _ = r.buttonDown(3, at: 0, triggers: [click1, click2])
        XCTAssertEqual(r.buttonUp(3, at: 0.05), [])
        XCTAssertEqual(r.nextDeadline, 0.35)
        XCTAssertEqual(r.tick(at: 0.2), [])
        XCTAssertEqual(r.tick(at: 0.35), [.fire(button: 3, trigger: click1)])
    }

    func testDoubleClickFires() {
        var r = makeRecognizer()
        _ = r.buttonDown(3, at: 0, triggers: [click2])
        _ = r.buttonUp(3, at: 0.05)
        _ = r.buttonDown(3, at: 0.2, triggers: [click2])
        XCTAssertEqual(r.buttonUp(3, at: 0.25), [.fire(button: 3, trigger: click2)])
    }

    func testUnmappedSingleClickIsReplayed() {
        var r = makeRecognizer()
        _ = r.buttonDown(3, at: 0, triggers: [click2])
        _ = r.buttonUp(3, at: 0.05)
        XCTAssertEqual(r.tick(at: 1), [.replayClick(button: 3)])
    }

    func testSlowSecondPressStartsNewCycle() {
        var r = makeRecognizer()
        _ = r.buttonDown(3, at: 0, triggers: [click1])
        XCTAssertEqual(r.buttonUp(3, at: 0.05), [.fire(button: 3, trigger: click1)])
        _ = r.buttonDown(3, at: 1, triggers: [click1])
        XCTAssertEqual(r.buttonUp(3, at: 1.05), [.fire(button: 3, trigger: click1)])
    }

    func testHoldFiresAfterDelayAndSuppressesClick() {
        var r = makeRecognizer()
        _ = r.buttonDown(5, at: 0, triggers: [click1, hold1])
        XCTAssertEqual(r.nextDeadline, 0.4)
        XCTAssertEqual(r.tick(at: 0.4), [.fire(button: 5, trigger: hold1)])
        XCTAssertEqual(r.buttonUp(5, at: 1), [])
        XCTAssertTrue(r.isIdle)
    }

    func testReleaseBeforeHoldDelayClicks() {
        var r = makeRecognizer()
        _ = r.buttonDown(5, at: 0, triggers: [click1, hold1])
        XCTAssertEqual(r.buttonUp(5, at: 0.1), [.fire(button: 5, trigger: click1)])
        XCTAssertEqual(r.tick(at: 0.5), [])
    }

    func testOtherButtonSettlesPendingCycle() {
        var r = makeRecognizer()
        _ = r.buttonDown(3, at: 0, triggers: [click1, click2])
        _ = r.buttonUp(3, at: 0.05)
        XCTAssertEqual(r.buttonDown(4, at: 0.1, triggers: [click1]), [.fire(button: 3, trigger: click1)])
    }

    func testCancelDropsEverything() {
        var r = makeRecognizer()
        _ = r.buttonDown(4, at: 0, triggers: [click1, hold1])
        r.cancel()
        XCTAssertEqual(r.buttonUp(4, at: 0.1), [])
        XCTAssertEqual(r.tick(at: 1), [])
    }
}
