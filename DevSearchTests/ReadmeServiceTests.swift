import Foundation
import XCTest
@testable import DevSearch

final class ReadmeServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testReadmePriority() throws {
        try Data("txt".utf8).write(to: directory.appendingPathComponent("README.txt"))
        try Data("markdown".utf8).write(to: directory.appendingPathComponent("README.md"))

        let result = try XCTUnwrap(ReadmeService.readme(in: directory))
        XCTAssertEqual(result.url.lastPathComponent, "README.md")
        XCTAssertEqual(result.excerpt, "markdown")
        XCTAssertFalse(result.wasTruncated)
    }

    func testCaseInsensitiveFallback() throws {
        try Data("lowercase".utf8).write(to: directory.appendingPathComponent("readme.md"))
        XCTAssertEqual(ReadmeService.readme(in: directory)?.excerpt, "lowercase")
    }

    func testTwentyKiBLimitPreservesUTF8Boundary() throws {
        let prefix = String(repeating: "a", count: ReadmeService.maximumBytes - 1)
        let content = prefix + "你" + "tail"
        try Data(content.utf8).write(to: directory.appendingPathComponent("README.md"))

        let result = try XCTUnwrap(ReadmeService.readme(in: directory))
        XCTAssertTrue(result.wasTruncated)
        XCTAssertEqual(result.excerpt, prefix)
        XCTAssertNotNil(result.excerpt.data(using: .utf8))
    }
}
