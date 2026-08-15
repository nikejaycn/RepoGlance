import XCTest
@testable import DevSearch

final class ToolboxSessionStoreTests: XCTestCase {
    func testStoreRoundTripAndClear() async throws {
        let url = temporaryURL()
        let store = ToolboxSessionStore(storageURL: url)
        let snapshot = ToolboxSessionSnapshot(
            qrText: "hello",
            encodingInput: "中文",
            timestampInput: "1723723200",
            timestampDate: Date(timeIntervalSince1970: 1_723_723_200),
            jsonInput: #"{"a":1}"#,
            uuidResults: ["fixed"],
            hashInput: "abc"
        )

        try await store.save(snapshot)
        let restoredSnapshot = try await store.load()
        let storedSize = await store.storedSize()
        XCTAssertEqual(restoredSnapshot, snapshot)
        XCTAssertGreaterThan(storedSize, 0)

        try await store.clear()
        let clearedSnapshot = try await store.load()
        let clearedSize = await store.storedSize()
        XCTAssertNil(clearedSnapshot)
        XCTAssertEqual(clearedSize, 0)
    }

    @MainActor
    func testToolboxModelRestoresLastSnapshotWhenEnabled() async {
        let url = temporaryURL()
        let store = ToolboxSessionStore(storageURL: url)
        let first = ToolboxModel(store: store)
        var preferences = ToolboxPreferences()
        preferences.restoreLastContent = true
        await first.start(preferences: preferences)
        first.qrText = "restored QR"
        first.jsonInput = #"{"restored":true}"#
        first.uuidResults = ["one", "two"]
        await first.persistNow()

        let second = ToolboxModel(store: store)
        await second.start(preferences: preferences)
        XCTAssertEqual(second.qrText, "restored QR")
        XCTAssertEqual(second.jsonInput, #"{"restored":true}"#)
        XCTAssertEqual(second.uuidResults, ["one", "two"])
    }

    @MainActor
    func testDisablingRestoreDeletesDiskSnapshotButKeepsCurrentMemory() async throws {
        let url = temporaryURL()
        let store = ToolboxSessionStore(storageURL: url)
        let model = ToolboxModel(store: store)
        var preferences = ToolboxPreferences()
        preferences.restoreLastContent = true
        await model.start(preferences: preferences)
        model.encodingInput = "keep in memory"
        await model.persistNow()

        await model.setRestoreEnabled(false)

        let storedSnapshot = try await store.load()
        XCTAssertEqual(model.encodingInput, "keep in memory")
        XCTAssertNil(storedSnapshot)
    }

    @MainActor
    func testOversizedContentIsNotPersisted() async throws {
        let url = temporaryURL()
        let store = ToolboxSessionStore(storageURL: url)
        let model = ToolboxModel(store: store)
        var preferences = ToolboxPreferences()
        preferences.restoreLastContent = true
        await model.start(preferences: preferences)
        model.hashInput = String(repeating: "a", count: ToolboxModel.maximumPersistedTextBytes + 1)
        await model.persistNow()

        let storedHashInput = try await store.load()?.hashInput
        XCTAssertTrue(model.oversizedTools.contains(.hash))
        XCTAssertEqual(storedHashInput, "")
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RepoGlance-ToolboxTests-\(UUID().uuidString).json")
    }
}
