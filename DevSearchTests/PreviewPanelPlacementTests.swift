import AppKit
import XCTest
@testable import DevSearch

final class PreviewPanelPlacementTests: XCTestCase {
    private let panelSize = NSSize(width: 400, height: 420)
    private let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)

    func testUsesRightSideWhenThereIsRoom() {
        let window = NSRect(x: 200, y: 200, width: 420, height: 520)
        let origin = PreviewPanelPlacement.origin(
            anchorWindowFrame: window,
            contentAnchorRect: nil,
            panelSize: panelSize,
            visibleScreenFrame: screen
        )

        XCTAssertEqual(origin.x, window.maxX + 8)
    }

    func testUsesLeftSideWhenRightSideWouldOverflow() {
        let window = NSRect(x: 900, y: 200, width: 420, height: 520)
        let origin = PreviewPanelPlacement.origin(
            anchorWindowFrame: window,
            contentAnchorRect: nil,
            panelSize: panelSize,
            visibleScreenFrame: screen
        )

        XCTAssertEqual(origin.x, window.minX - panelSize.width - 8)
    }

    func testClampsVerticalPlacementInsideVisibleScreen() {
        let window = NSRect(x: 200, y: 20, width: 420, height: 520)
        let lowRow = NSRect(x: 200, y: 10, width: 420, height: 52)
        let origin = PreviewPanelPlacement.origin(
            anchorWindowFrame: window,
            contentAnchorRect: lowRow,
            panelSize: panelSize,
            visibleScreenFrame: screen
        )

        XCTAssertGreaterThanOrEqual(origin.y, 16)
        XCTAssertLessThanOrEqual(origin.y + panelSize.height, screen.maxY - 16)
    }
}
