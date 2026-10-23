import XCTest
@testable import MacMouseCore

final class ScrollAnimatorTests: XCTestCase {
    private func drain(_ animator: inout ScrollAnimator, frames: Int = 600) -> (x: Int, y: Int, steps: [Int]) {
        var total = (x: 0, y: 0)
        var steps: [Int] = []
        for _ in 0..<frames where !animator.isIdle {
            let d = animator.step(dt: 1.0 / 120)
            total.x += d.dx
            total.y += d.dy
            steps.append(d.dy)
        }
        return (total.x, total.y, steps)
    }

    func testEmitsExactDistanceForOneNotch() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 64, timeConstant: 0.1))
        a.addNotches(dx: 0, dy: 1, at: 0)
        let result = drain(&a)
        XCTAssertEqual(result.y, 64)
        XCTAssertEqual(result.x, 0)
        XCTAssertTrue(a.isIdle)
    }

    func testGlideDecelerates() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 100, timeConstant: 0.1))
        a.addNotches(dx: 0, dy: -1, at: 0)
        let steps = drain(&a).steps.map(abs)
        XCTAssertGreaterThan(steps.count, 5, "should animate over several frames")
        XCTAssertGreaterThan(steps.first!, steps[steps.count / 2])
    }

    func testZeroTimeConstantJumps() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 40, timeConstant: 0))
        a.addNotches(dx: 1, dy: 0, at: 0)
        XCTAssertEqual(a.step(dt: 0.008).dx, 40)
        XCTAssertTrue(a.isIdle)
    }

    func testFlicksAccelerate() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 10, timeConstant: 0.1))
        a.addNotches(dx: 0, dy: 1, at: 0)
        a.addNotches(dx: 0, dy: 1, at: 0.03)
        a.addNotches(dx: 0, dy: 1, at: 0.06)
        XCTAssertGreaterThan(a.currentMultiplier, 1)
        XCTAssertGreaterThan(drain(&a).y, 30)
    }

    func testSlowNotchesDoNotAccelerate() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 10, timeConstant: 0.1))
        a.addNotches(dx: 0, dy: 1, at: 0)
        a.addNotches(dx: 0, dy: 1, at: 0.5)
        XCTAssertEqual(a.currentMultiplier, 1)
        XCTAssertEqual(drain(&a).y, 20)
    }

    func testReversingDropsPreviousGlide() {
        var a = ScrollAnimator(tuning: .init(pixelsPerNotch: 50, timeConstant: 0.1))
        a.addNotches(dx: 0, dy: 1, at: 0)
        a.addNotches(dx: 0, dy: -1, at: 0.01)
        XCTAssertEqual(drain(&a).y, -50)
    }
}

final class DragDirectionRecognizerTests: XCTestCase {
    func testRecognizesDominantAxisOnce() {
        var r = DragDirectionRecognizer(threshold: 50)
        XCTAssertNil(r.add(dx: 10, dy: -5))
        XCTAssertEqual(r.add(dx: 5, dy: -50), .up)
        XCTAssertNil(r.add(dx: 200, dy: 0), "only one direction per drag")
        r.reset()
        XCTAssertEqual(r.add(dx: -80, dy: 10), .left)
    }

    func testGestureMapping() {
        XCTAssertEqual(DragDirection.up.gestureAction, .missionControl)
        XCTAssertEqual(DragDirection.down.gestureAction, .appWindows)
        XCTAssertEqual(DragDirection.left.gestureAction, .spaceRight)
        XCTAssertEqual(DragDirection.right.gestureAction, .spaceLeft)
    }
}

final class ScrollModeTests: XCTestCase {
    func testDefaultModifiers() {
        let s = ScrollSettings()
        XCTAssertEqual(s.mode(for: []), ScrollMode())
        XCTAssertEqual(s.mode(for: .shift), ScrollMode(horizontal: true))
        XCTAssertEqual(s.mode(for: .option), ScrollMode(precise: true))
        XCTAssertEqual(s.mode(for: [.control, .shift]), ScrollMode(horizontal: true, fast: true))
    }

    func testCommandZoomsByDefault() {
        let s = ScrollSettings()
        XCTAssertEqual(s.mode(for: .command), ScrollMode(zoom: true))
    }

    func testUnassignedModifierPassesThrough() {
        var s = ScrollSettings()
        s.zoomModifier = .none
        XCTAssertTrue(s.mode(for: .command).passThrough)
        XCTAssertTrue(s.mode(for: [.command, .shift]).passThrough)
    }

    func testOlderConfigWithoutZoomModifierDecodes() throws {
        let json = #"{"smoothness":"off","speed":"fast","reverseDirection":true,"#
            + #""horizontalModifier":"shift","preciseModifier":"option","fastModifier":"control"}"#
        let s = try JSONDecoder().decode(ScrollSettings.self, from: Data(json.utf8))
        XCTAssertTrue(s.reverseDirection)
        XCTAssertEqual(s.speed, .fast)
        XCTAssertEqual(s.zoomModifier, .command)
    }

    func testDisabledModifier() {
        var s = ScrollSettings()
        s.horizontalModifier = .none
        XCTAssertEqual(s.mode(for: .shift), ScrollMode(passThrough: true))
    }

    func testEventFlagsAreMasked() {
        let deviceBits: UInt64 = 0x100 | 0x800000 // device-dependent + fn
        XCTAssertEqual(ModifierSet(eventFlags: ModifierSet.shift.rawValue | deviceBits), .shift)
    }
}
