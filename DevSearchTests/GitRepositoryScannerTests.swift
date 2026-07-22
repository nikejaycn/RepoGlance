import Foundation
import XCTest
@testable import DevSearch

final class GitRepositoryScannerTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testFindsDirectoryAndValidGitFileRepositoriesWithParentRelationship() async throws {
        let parent = rootURL.appendingPathComponent("WebApp", isDirectory: true)
        let child = parent.appendingPathComponent("services/API", isDirectory: true)
        let worktree = rootURL.appendingPathComponent("Worktree", isDirectory: true)
        let gitDirectory = rootURL.appendingPathComponent("metadata/worktree-git", isDirectory: true)

        try createGitDirectory(at: parent)
        try createGitDirectory(at: child)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: gitDirectory, withIntermediateDirectories: true)
        try Data("gitdir: ../metadata/worktree-git\n".utf8).write(to: worktree.appendingPathComponent(".git"))

        let scanner = GitRepositoryScanner()
        let root = ScanRoot(canonicalPath: PathNormalizer.canonicalPath(for: rootURL))
        let result = await scanner.scan(roots: [root], exclusions: [])

        XCTAssertEqual(result.projects.count, 3)
        let parentPath = PathNormalizer.canonicalPath(for: parent)
        let childProject = try XCTUnwrap(result.projects.first { $0.canonicalPath == PathNormalizer.canonicalPath(for: child) })
        XCTAssertEqual(childProject.parentProjectID, parentPath)
        XCTAssertTrue(result.projects.contains { $0.canonicalPath == PathNormalizer.canonicalPath(for: worktree) })
    }

    func testRejectsOrdinaryDotGitFile() async throws {
        let fake = rootURL.appendingPathComponent("Fake", isDirectory: true)
        try FileManager.default.createDirectory(at: fake, withIntermediateDirectories: true)
        try Data("not a git pointer".utf8).write(to: fake.appendingPathComponent(".git"))

        let result = await GitRepositoryScanner().scan(
            roots: [ScanRoot(canonicalPath: PathNormalizer.canonicalPath(for: rootURL))],
            exclusions: []
        )
        XCTAssertTrue(result.projects.isEmpty)
    }

    func testExcludesOnlyProjectOrWholeSubtree() async throws {
        let parent = rootURL.appendingPathComponent("Parent", isDirectory: true)
        let child = parent.appendingPathComponent("Child", isDirectory: true)
        try createGitDirectory(at: parent)
        try createGitDirectory(at: child)

        let parentPath = PathNormalizer.canonicalPath(for: parent)
        let root = ScanRoot(canonicalPath: PathNormalizer.canonicalPath(for: rootURL))
        let scanner = GitRepositoryScanner()

        let exact = await scanner.scan(
            roots: [root],
            exclusions: [ExclusionRule(canonicalPath: parentPath, includesDescendants: false)]
        )
        XCTAssertEqual(exact.projects.map(\.directoryName), ["Child"])

        let subtree = await scanner.scan(
            roots: [root],
            exclusions: [ExclusionRule(canonicalPath: parentPath, includesDescendants: true)]
        )
        XCTAssertTrue(subtree.projects.isEmpty)
    }

    func testHonorsMaximumDepthAndIgnoredDirectoryNames() async throws {
        let topLevel = rootURL.appendingPathComponent("Top", isDirectory: true)
        let tooDeep = rootURL.appendingPathComponent("group/Deep", isDirectory: true)
        let dependency = rootURL.appendingPathComponent("node_modules/Dependency", isDirectory: true)
        try createGitDirectory(at: topLevel)
        try createGitDirectory(at: tooDeep)
        try createGitDirectory(at: dependency)

        let root = ScanRoot(
            canonicalPath: PathNormalizer.canonicalPath(for: rootURL),
            maximumDepth: 1
        )
        let result = await GitRepositoryScanner().scan(roots: [root], exclusions: [])

        XCTAssertEqual(result.projects.map(\.directoryName), ["Top"])
    }

    func testIgnoresConfiguredRelativePathWithoutHidingSameNamedDirectoryElsewhere() async throws {
        let ignored = rootURL.appendingPathComponent("teams/legacy/Archived", isDirectory: true)
        let retained = rootURL.appendingPathComponent("clients/legacy/Active", isDirectory: true)
        try createGitDirectory(at: ignored)
        try createGitDirectory(at: retained)

        let root = ScanRoot(
            canonicalPath: PathNormalizer.canonicalPath(for: rootURL),
            ignoredRelativePaths: ["teams/legacy"]
        )
        let result = await GitRepositoryScanner().scan(roots: [root], exclusions: [])

        XCTAssertEqual(result.projects.map(\.directoryName), ["Active"])
    }

    func testHiddenRepositoriesRequireExplicitOptIn() async throws {
        let hidden = rootURL.appendingPathComponent(".Secret", isDirectory: true)
        try createGitDirectory(at: hidden)
        let canonicalRoot = PathNormalizer.canonicalPath(for: rootURL)
        let scanner = GitRepositoryScanner()

        let defaultResult = await scanner.scan(
            roots: [ScanRoot(canonicalPath: canonicalRoot)],
            exclusions: []
        )
        XCTAssertTrue(defaultResult.projects.isEmpty)

        let optInResult = await scanner.scan(
            roots: [ScanRoot(canonicalPath: canonicalRoot, scanHiddenDirectories: true)],
            exclusions: []
        )
        XCTAssertEqual(optInResult.projects.map(\.directoryName), [".Secret"])
    }

    func testUnavailableRootProducesActionableIssueWithoutCrashing() async {
        let missing = rootURL.appendingPathComponent("Removed", isDirectory: true)
        let missingPath = PathNormalizer.canonicalPath(for: missing)

        let result = await GitRepositoryScanner().scan(
            roots: [ScanRoot(canonicalPath: missingPath)],
            exclusions: []
        )

        XCTAssertTrue(result.projects.isEmpty)
        XCTAssertEqual(result.issues.first?.kind, .rootUnavailable)
        XCTAssertEqual(result.issues.first?.rootPath, missingPath)
    }

    func testStreamsRepositoriesAsTheyAreDiscovered() async throws {
        let parent = rootURL.appendingPathComponent("Workspace", isDirectory: true)
        let child = parent.appendingPathComponent("API", isDirectory: true)
        try createGitDirectory(at: parent)
        try createGitDirectory(at: child)
        let collector = DiscoveredProjectCollector()

        _ = await GitRepositoryScanner().scan(
            roots: [ScanRoot(canonicalPath: PathNormalizer.canonicalPath(for: rootURL))],
            exclusions: [],
            onDiscovery: { project in await collector.append(project) }
        )
        let streamed = await collector.projects

        XCTAssertEqual(streamed.map(\.directoryName), ["Workspace", "API"])
        XCTAssertEqual(streamed.last?.parentProjectID, streamed.first?.id)
    }

    private func createGitDirectory(at projectURL: URL) throws {
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
    }
}

private actor DiscoveredProjectCollector {
    private(set) var projects: [ProjectRecord] = []

    func append(_ project: ProjectRecord) {
        projects.append(project)
    }
}
