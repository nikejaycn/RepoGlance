import XCTest
@testable import DevSearch

final class LimitedMarkdownTests: XCTestCase {
    func testRemovesExecutableHTMLAndRemoteImages() {
        let input = "# Title\n<script>alert(1)</script>\n![diagram](https://example.com/a.png)"
        let output = LimitedMarkdown.sanitize(input)

        XCTAssertTrue(output.contains("# Title"))
        XCTAssertTrue(output.contains("diagram"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("script"))
        XCTAssertFalse(output.contains("https://"))
    }

    func testRendersLinksAsPlainLabels() {
        let output = LimitedMarkdown.sanitize("See [documentation](javascript:alert) now")
        XCTAssertEqual(output, "See documentation now")
        XCTAssertFalse(output.contains("javascript:"))
    }
}
