import AppKit
import XCTest
@testable import DevSearch

@MainActor
final class ApplicationLifecycleTests: XCTestCase {
    func testClosingAllWindowsDoesNotTerminateMenuBarApp() {
        let delegate = DevSearchApplicationDelegate()

        XCTAssertFalse(
            delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        )
    }
}
