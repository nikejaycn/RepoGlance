import XCTest
@testable import DevSearch

final class ClipboardSearchServiceTests: XCTestCase {
    func testSearchIsCaseInsensitiveAndPreservesRecencyOrder() {
        let newest = ClipboardItem(text: "RepoGlance Release")
        let older = ClipboardItem(text: "repoglance notes")
        let unrelated = ClipboardItem(text: "other")

        let result = ClipboardSearchService.search(
            [newest, unrelated, older],
            query: "REPOGLANCE"
        )

        XCTAssertEqual(result.map(\.id), [newest.id, older.id])
    }

    func testEmptyQueryAndLimitReturnNewestPrefix() {
        let items = (0..<5).map { ClipboardItem(text: "\($0)") }
        XCTAssertEqual(
            ClipboardSearchService.search(items, query: "  ", limit: 2).map(\.text),
            ["0", "1"]
        )
    }

    func testTenThousandItemSearchMeetsFiftyMillisecondTarget() {
        let items = (0..<10_000).map {
            ClipboardItem(text: $0 == 9_999 ? "unique efficiency needle" : "clipboard item \($0)")
        }

        let start = ContinuousClock.now
        let result = ClipboardSearchService.search(items, query: "efficiency needle")
        let elapsed = start.duration(to: .now)

        XCTAssertEqual(result.count, 1)
        XCTAssertLessThan(elapsed, .milliseconds(50))
    }
}
