import XCTest
@testable import MacMouseCore

final class ConfigTests: XCTestCase {
    func testDefaultsInterceptOnlyConfiguredExtraButtons() {
        let config = MouseConfig.defaults
        XCTAssertFalse(config.intercepts(button: 1))
        XCTAssertFalse(config.intercepts(button: 2))
        XCTAssertTrue(config.intercepts(button: 3))
        XCTAssertTrue(config.intercepts(button: 4))
        XCTAssertTrue(config.intercepts(button: 5))
        XCTAssertFalse(config.intercepts(button: 6))
    }

    func testPrimaryButtonsNeverIntercepted() {
        var config = MouseConfig()
        config.mappings = [ButtonMapping(button: 1, trigger: ButtonTrigger(.click), action: .back)]
        XCTAssertFalse(config.intercepts(button: 1))
    }

    func testActionLookup() {
        let config = MouseConfig.defaults
        XCTAssertEqual(config.action(for: 4, trigger: ButtonTrigger(.click)), .back)
        XCTAssertNil(config.action(for: 4, trigger: ButtonTrigger(.hold)))
    }

    func testTriggerClampsClicks() {
        XCTAssertEqual(ButtonTrigger(.click, clicks: 9).clicks, 3)
        XCTAssertEqual(ButtonTrigger(.click, clicks: 0).clicks, 1)
    }

    func testRoutes() {
        XCTAssertEqual(MouseAction.missionControl.route, .systemHotKey(.missionControl))
        XCTAssertEqual(MouseAction.back.route, .keystroke(keyCode: KeyCode.leftBracket, modifiers: .command))
        let custom = KeyShortcut(keyCode: 0x00, modifiers: [.command, .shift], keyLabel: "A")
        XCTAssertEqual(MouseAction.shortcut(custom).route, .keystroke(keyCode: 0x00, modifiers: [.command, .shift]))
        XCTAssertEqual(custom.displayString, "⇧⌘A")
    }

    func testStoreRoundTripAndFallback() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ConfigStore(fileURL: dir.appendingPathComponent("config.json"))

        let missing = await store.load()
        XCTAssertEqual(missing, .defaults.withSameIDs(as: missing))

        var config = MouseConfig.defaults
        config.scroll.reverseDirection = true
        config.mappings.append(ButtonMapping(
            button: 6, trigger: ButtonTrigger(.hold, clicks: 2),
            action: .shortcut(KeyShortcut(keyCode: 0x31, modifiers: .control, keyLabel: "SPACE"))
        ))
        try await store.save(config)
        let loaded = await store.load()
        XCTAssertEqual(loaded, config)

        try Data("not json".utf8).write(to: dir.appendingPathComponent("config.json"))
        let corrupt = await store.load()
        XCTAssertEqual(corrupt.mappings.count, MouseConfig.defaults.mappings.count)
    }
}

private extension MouseConfig {
    /// Defaults generate fresh UUIDs; align them for equality checks.
    func withSameIDs(as other: MouseConfig) -> MouseConfig {
        var copy = self
        for i in copy.mappings.indices where i < other.mappings.count {
            copy.mappings[i].id = other.mappings[i].id
        }
        return copy
    }
}
