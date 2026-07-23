import XCTest
@testable import DevSearch

final class ClipboardHistoryServiceTests: XCTestCase {
    func testInsertingPlacesNewestFirstAndPreservesText() {
        let date = Date(timeIntervalSince1970: 100)
        let id = UUID()
        let result = ClipboardHistoryService.inserting(
            "  hello\nworld  ",
            into: [],
            limit: 10,
            copiedAt: date,
            id: id
        )

        XCTAssertEqual(result, [
            ClipboardItem(id: id, text: "  hello\nworld  ", copiedAt: date)
        ])
    }

    func testDuplicateIsMovedToFrontWithoutGrowingHistory() {
        let old = ClipboardItem(text: "same", copiedAt: .distantPast)
        let other = ClipboardItem(text: "other", copiedAt: .distantPast)

        let result = ClipboardHistoryService.inserting(
            "same",
            into: [other, old],
            limit: 10,
            copiedAt: .now
        )

        XCTAssertEqual(result.map(\.text), ["same", "other"])
        XCTAssertEqual(result.count, 2)
    }

    func testLimitAndInvalidTextAreEnforced() {
        let existing = [
            ClipboardItem(text: "one"),
            ClipboardItem(text: "two")
        ]

        XCTAssertEqual(
            ClipboardHistoryService.inserting("three", into: existing, limit: 2).map(\.text),
            ["three", "one"]
        )
        XCTAssertEqual(
            ClipboardHistoryService.inserting(" \n ", into: existing, limit: 2),
            existing
        )
        XCTAssertEqual(
            ClipboardHistoryService.inserting(
                String(repeating: "a", count: ClipboardHistoryService.maximumTextBytes + 1),
                into: existing,
                limit: 2
            ),
            existing
        )
    }
}
