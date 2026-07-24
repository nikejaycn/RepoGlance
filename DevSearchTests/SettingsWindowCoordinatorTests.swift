import AppKit
import XCTest
@testable import DevSearch

@MainActor
final class SettingsWindowCoordinatorTests: XCTestCase {
    func testShowCreatesVisibleSettingsWindow() {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-window-\(UUID().uuidString).json")
        let model = AppModel(store: ProjectStore(storageURL: storageURL))
        let coordinator = SettingsWindowCoordinator()

        coordinator.show(model: model)

        XCTAssertTrue(coordinator.isVisible)

        coordinator.close()
        XCTAssertFalse(coordinator.isVisible)

        coordinator.show(model: model)
        XCTAssertTrue(coordinator.isVisible)
        coordinator.close()
    }
}
