import Foundation
import XCTest
@testable import DevSearch

final class ProjectStoreTests: XCTestCase {
    func testRoundTripPersistsUserMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("data.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ProjectStore(storageURL: url)
        var project = ProjectRecord(canonicalPath: "/tmp/project", directoryName: "project", scanRootPath: "/tmp")
        project.displayName = "My Project"
        project.customDescription = "Description"
        project.tags = ["macOS"]
        project.isFavorite = true
        let clipboardItem = ClipboardItem(text: "saved text")
        let data = AppData(projects: [project], clipboardItems: [clipboardItem])

        try await store.save(data)
        let restored = try await store.load()
        XCTAssertEqual(restored.projects.first?.displayName, "My Project")
        XCTAssertEqual(restored.projects.first?.tags, ["macOS"])
        XCTAssertEqual(restored.projects.first?.isFavorite, true)
        XCTAssertEqual(restored.clipboardItems.first?.id, clipboardItem.id)
        XCTAssertEqual(restored.clipboardItems.first?.text, clipboardItem.text)
        XCTAssertEqual(
            restored.clipboardItems.first?.copiedAt.timeIntervalSince1970 ?? 0,
            clipboardItem.copiedAt.timeIntervalSince1970,
            accuracy: 1
        )
    }
}
