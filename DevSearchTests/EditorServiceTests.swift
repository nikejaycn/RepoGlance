import Foundation
import XCTest
@testable import DevSearch

final class EditorServiceTests: XCTestCase {
    @MainActor
    func testSpecialCharacterProjectPathIsPassedUnchangedToEditorAndTerminal() async throws {
        let fixture = try makeFixture(named: "项目 $HOME [测试] 'quote' & more")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let recorder = WorkspaceRecorder()
        let service = EditorService(workspace: recorder.client)
        let project = makeProject(at: fixture)

        try await service.open(project: project, editorBundleIdentifier: "com.example.Editor")
        try await service.openInTerminal(project, terminalBundleIdentifier: "com.example.Terminal")

        XCTAssertEqual(recorder.openedURLs.map(\.first?.path), [fixture.path, fixture.path])
        XCTAssertEqual(
            recorder.applicationURLs.map(\.path),
            ["/Applications/com.example.Editor.app", "/Applications/com.example.Terminal.app"]
        )
    }

    @MainActor
    func testFinderAndDefaultFileOpeningReceiveExactURLs() async throws {
        let fixture = try makeFixture(named: "中文 project ; $(safe)")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let readme = fixture.appendingPathComponent("README [本地].md")
        try Data("hello".utf8).write(to: readme)
        let recorder = WorkspaceRecorder()
        let service = EditorService(workspace: recorder.client)
        let project = makeProject(at: fixture)

        try await service.open(project: project, editorBundleIdentifier: nil)
        service.revealInFinder(project)
        try await service.openFile(readme, editorBundleIdentifier: nil)

        XCTAssertEqual(recorder.revealedURLs.map(\.path), [fixture.path, fixture.path])
        XCTAssertEqual(recorder.directlyOpenedFiles.map(\.path), [readme.path])
    }

    @MainActor
    func testUnavailableEditorProducesActionableErrorWithoutOpeningAnything() async throws {
        let fixture = try makeFixture(named: "Unavailable Editor")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let recorder = WorkspaceRecorder(availableApplications: [])
        let service = EditorService(workspace: recorder.client)

        do {
            try await service.open(
                project: makeProject(at: fixture),
                editorBundleIdentifier: "com.example.Missing"
            )
            XCTFail("Expected editorUnavailable")
        } catch let error as EditorError {
            XCTAssertEqual(error.errorDescription, "找不到所选编辑器，请在设置中重新选择。")
        }
        XCTAssertTrue(recorder.openedURLs.isEmpty)
    }

    private func makeFixture(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevSearchEditorTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeProject(at url: URL) -> ProjectRecord {
        ProjectRecord(
            canonicalPath: url.path,
            directoryName: url.lastPathComponent,
            scanRootPath: url.deletingLastPathComponent().path
        )
    }
}

@MainActor
private final class WorkspaceRecorder {
    let availableApplications: Set<String>
    var openedURLs: [[URL]] = []
    var applicationURLs: [URL] = []
    var revealedURLs: [URL] = []
    var directlyOpenedFiles: [URL] = []

    init(availableApplications: Set<String> = ["com.example.Editor", "com.example.Terminal"]) {
        self.availableApplications = availableApplications
    }

    var client: WorkspaceClient {
        WorkspaceClient(
            applicationURL: { [weak self] identifier in
                guard self?.availableApplications.contains(identifier) == true else { return nil }
                return URL(fileURLWithPath: "/Applications/\(identifier).app")
            },
            reveal: { [weak self] urls in self?.revealedURLs.append(contentsOf: urls) },
            openURLs: { [weak self] urls, applicationURL in
                self?.openedURLs.append(urls)
                self?.applicationURLs.append(applicationURL)
            },
            openFile: { [weak self] url in self?.directlyOpenedFiles.append(url) }
        )
    }
}
