import XCTest
@testable import DevSearch

final class PathNormalizerTests: XCTestCase {
    func testCanonicalPathResolvesDotSegmentsAndTrailingSlash() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let input = root.appendingPathComponent("folder/../project/", isDirectory: true)
        let result = PathNormalizer.canonicalPath(for: input)
        XCTAssertTrue(result.hasSuffix("/project"))
        XCTAssertFalse(result.hasSuffix("/"))
    }

    func testDescendantRequiresPathBoundary() {
        XCTAssertTrue(PathNormalizer.isDescendant("/work/app/api", of: "/work/app"))
        XCTAssertFalse(PathNormalizer.isDescendant("/work/application", of: "/work/app"))
        XCTAssertFalse(PathNormalizer.isDescendant("/work/app", of: "/work/app"))
    }

    func testCanonicalPathUsesFileSystemSpellingOnCaseInsensitiveVolume() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevSearch-Case-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let alternateCase = URL(fileURLWithPath: root.path.lowercased(), isDirectory: true)
        guard FileManager.default.fileExists(atPath: alternateCase.path) else {
            // On a case-sensitive volume the two spellings correctly identify
            // different paths, so there is no case folding to verify.
            return
        }

        XCTAssertEqual(
            PathNormalizer.canonicalPath(for: alternateCase),
            PathNormalizer.canonicalPath(for: root)
        )
    }
}
