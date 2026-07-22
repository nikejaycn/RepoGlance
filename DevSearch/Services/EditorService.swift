@preconcurrency import AppKit
import Foundation

@MainActor
final class EditorService {
    static let knownEditors: [(name: String, bundleIdentifier: String)] = [
        ("Visual Studio Code", "com.microsoft.VSCode"),
        ("Cursor", "com.todesktop.230313mzl4w4u92"),
        ("Windsurf", "com.exafunction.windsurf"),
        ("Zed", "dev.zed.Zed"),
        ("Xcode", "com.apple.dt.Xcode"),
        ("IntelliJ IDEA", "com.jetbrains.intellij"),
        ("WebStorm", "com.jetbrains.WebStorm"),
        ("PyCharm", "com.jetbrains.pycharm")
    ]

    private let workspace: WorkspaceClient
    private let fileManager: FileManager

    init(workspace: WorkspaceClient = .live, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func discoverEditors() -> [EditorDefinition] {
        Self.knownEditors.compactMap { editor in
            guard let url = workspace.applicationURL(editor.bundleIdentifier) else {
                return nil
            }
            return EditorDefinition(
                id: editor.bundleIdentifier,
                name: editor.name,
                bundleIdentifier: editor.bundleIdentifier,
                applicationPath: url.path,
                isManuallyAdded: false
            )
        }
    }

    func applicationPath(for bundleIdentifier: String) -> String? {
        workspace.applicationURL(bundleIdentifier)?.path
    }

    func open(project: ProjectRecord, editorBundleIdentifier: String?) async throws {
        guard project.availability == .available else { throw EditorError.projectUnavailable }
        let projectURL = URL(fileURLWithPath: project.canonicalPath, isDirectory: true)
        guard fileManager.fileExists(atPath: projectURL.path) else { throw EditorError.projectUnavailable }

        guard let editorBundleIdentifier else {
            workspace.reveal([projectURL])
            return
        }

        guard let applicationURL = workspace.applicationURL(editorBundleIdentifier) else {
            throw EditorError.editorUnavailable(editorBundleIdentifier)
        }
        try await workspace.openURLs([projectURL], applicationURL)
    }

    func revealInFinder(_ project: ProjectRecord) {
        workspace.reveal([URL(fileURLWithPath: project.canonicalPath)])
    }

    func openFile(_ fileURL: URL, editorBundleIdentifier: String?) async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw EditorError.projectUnavailable
        }
        guard let editorBundleIdentifier else {
            workspace.openFile(fileURL)
            return
        }
        guard let applicationURL = workspace.applicationURL(editorBundleIdentifier) else {
            throw EditorError.editorUnavailable(editorBundleIdentifier)
        }
        try await workspace.openURLs([fileURL], applicationURL)
    }

    func openInTerminal(_ project: ProjectRecord, terminalBundleIdentifier: String) async throws {
        guard project.availability == .available else { throw EditorError.projectUnavailable }
        let projectURL = URL(fileURLWithPath: project.canonicalPath, isDirectory: true)
        guard fileManager.fileExists(atPath: projectURL.path) else { throw EditorError.projectUnavailable }
        guard let terminalURL = workspace.applicationURL(terminalBundleIdentifier) else {
            throw EditorError.editorUnavailable(terminalBundleIdentifier)
        }
        try await workspace.openURLs([projectURL], terminalURL)
    }
}

@MainActor
struct WorkspaceClient {
    var applicationURL: (String) -> URL?
    var reveal: ([URL]) -> Void
    var openURLs: ([URL], URL) async throws -> Void
    var openFile: (URL) -> Void

    static let live = WorkspaceClient(
        applicationURL: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        reveal: { NSWorkspace.shared.activateFileViewerSelecting($0) },
        openURLs: { urls, applicationURL in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            try await NSWorkspace.shared.open(
                urls,
                withApplicationAt: applicationURL,
                configuration: configuration
            )
        },
        openFile: { _ = NSWorkspace.shared.open($0) }
    )
}

enum EditorError: LocalizedError {
    case projectUnavailable
    case editorUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .projectUnavailable:
            return "项目路径当前不可用。"
        case .editorUnavailable:
            return "找不到所选编辑器，请在设置中重新选择。"
        }
    }
}
