import XCTest
@testable import DevSearch

final class IndexMergeServiceTests: XCTestCase {
    func testExcludedExistingProjectIsRemovedInsteadOfRetainedAsMissing() {
        let root = "/tmp/dev"
        let project = makeProject(path: root + "/secret", root: root)

        let merged = IndexMergeService.merge(
            existing: [project],
            scanned: [],
            activeRootPaths: [root],
            exclusions: [ExclusionRule(canonicalPath: project.canonicalPath, includesDescendants: false)],
            issues: []
        )

        XCTAssertTrue(merged.isEmpty)
    }

    func testSubtreeExclusionRemovesParentAndDescendants() {
        let root = "/tmp/dev"
        let parent = makeProject(path: root + "/app", root: root)
        let child = makeProject(path: root + "/app/packages/api", root: root)

        let merged = IndexMergeService.merge(
            existing: [parent, child],
            scanned: [],
            activeRootPaths: [root],
            exclusions: [ExclusionRule(canonicalPath: parent.canonicalPath, includesDescendants: true)],
            issues: []
        )

        XCTAssertTrue(merged.isEmpty)
    }

    func testDisabledRootRecordsRemainAvailableWhenRootWasNotScanned() {
        let root = "/tmp/paused"
        let project = makeProject(path: root + "/app", root: root)

        let merged = IndexMergeService.merge(
            existing: [project],
            scanned: [],
            activeRootPaths: [],
            exclusions: [],
            issues: []
        )

        XCTAssertEqual(merged.first?.availability, .available)
    }

    func testMissingProjectInActiveRootIsMarkedUnavailableAndKeepsMetadata() {
        let root = "/tmp/dev"
        var project = makeProject(path: root + "/moved", root: root)
        project.customDescription = "保留我"
        project.tags = ["legacy"]
        project.isFavorite = true

        let merged = IndexMergeService.merge(
            existing: [project],
            scanned: [],
            activeRootPaths: [root],
            exclusions: [],
            issues: []
        )

        XCTAssertEqual(merged.first?.availability, .missing)
        XCTAssertEqual(merged.first?.customDescription, "保留我")
        XCTAssertEqual(merged.first?.tags, ["legacy"])
        XCTAssertEqual(merged.first?.isFavorite, true)
    }

    func testOfflineExternalVolumeUsesDistinctAvailability() {
        let root = "/Volumes/Work/code"
        let project = makeProject(path: root + "/app", root: root)
        let issue = ScanIssue(rootPath: root, path: root, kind: .rootUnavailable, message: "扫描目录不可用")

        let merged = IndexMergeService.merge(
            existing: [project],
            scanned: [],
            activeRootPaths: [root],
            exclusions: [],
            issues: [issue]
        )

        XCTAssertEqual(merged.first?.availability, .volumeOffline)
    }

    func testRescannedProjectPreservesUserMetadata() {
        let root = "/tmp/dev"
        var old = makeProject(path: root + "/app", root: root)
        old.displayName = "工作台"
        old.customDescription = "内部工具"
        old.tags = ["work"]
        old.isFavorite = true
        old.defaultEditorBundleIdentifier = "com.microsoft.VSCode"
        old.lastOpenedAt = Date(timeIntervalSince1970: 42)

        let rescanned = makeProject(path: old.canonicalPath, root: root)
        let merged = IndexMergeService.merge(
            existing: [old],
            scanned: [rescanned],
            activeRootPaths: [root],
            exclusions: [],
            issues: []
        )

        XCTAssertEqual(merged.first?.displayName, "工作台")
        XCTAssertEqual(merged.first?.customDescription, "内部工具")
        XCTAssertEqual(merged.first?.tags, ["work"])
        XCTAssertEqual(merged.first?.isFavorite, true)
        XCTAssertEqual(merged.first?.defaultEditorBundleIdentifier, "com.microsoft.VSCode")
        XCTAssertEqual(merged.first?.lastOpenedAt, old.lastOpenedAt)
    }

    func testDuplicateExistingAndScannedRecordsAreMergedWithoutTrapping() {
        let root = "/tmp/dev"
        var oldFirst = makeProject(path: root + "/app", root: root)
        oldFirst.customDescription = "old"
        var oldLast = oldFirst
        oldLast.customDescription = "new"

        let scannedFirst = ProjectRecord(
            canonicalPath: oldFirst.canonicalPath,
            directoryName: "Old Name",
            scanRootPath: root
        )
        let scannedLast = ProjectRecord(
            canonicalPath: oldFirst.canonicalPath,
            directoryName: "New Name",
            scanRootPath: root
        )

        let merged = IndexMergeService.merge(
            existing: [oldFirst, oldLast],
            scanned: [scannedFirst, scannedLast],
            activeRootPaths: [root],
            exclusions: [],
            issues: []
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.directoryName, "New Name")
        XCTAssertEqual(merged.first?.customDescription, "new")
    }

    private func makeProject(path: String, root: String) -> ProjectRecord {
        ProjectRecord(
            canonicalPath: path,
            directoryName: URL(fileURLWithPath: path).lastPathComponent,
            scanRootPath: root
        )
    }
}
