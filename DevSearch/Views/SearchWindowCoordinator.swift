import AppKit
import SwiftUI

@MainActor
final class SearchWindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = SearchWindowCoordinator()
    private var panel: NSPanel?

    private var isUIAcceptanceMode: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-search")
#else
        false
#endif
    }

    func toggle(model: AppModel) {
        if let panel, panel.isVisible {
            hide()
            return
        }
        show(model: model)
    }

    func hide() {
        panel?.orderOut(nil)
        PreviewPanelCoordinator.shared.hideImmediately()
    }

    func show(model: AppModel) {
        let content = SearchPanelView().environmentObject(model)
        let hosting = NSHostingView(rootView: content)
        let target: NSPanel
        if let panel {
            panel.contentView = hosting
            target = panel
        } else {
            let created = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.isMovableByWindowBackground = false
            created.hidesOnDeactivate = !isUIAcceptanceMode
            created.level = .floating
            created.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
            created.delegate = self
            created.contentView = hosting
            panel = created
            target = created
        }

        position(target)
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    func restoreSearchFocus() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
        if let searchField = findSearchField(in: panel.contentView) {
            panel.makeFirstResponder(searchField)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel else { return }
        guard !PreviewPanelCoordinator.shared.isInteractive else { return }
        guard !isUIAcceptanceMode else { return }
        PreviewPanelCoordinator.shared.hideImmediately()
        window.orderOut(nil)
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = min(max(mouse.x - panel.frame.width / 2, visible.minX + 16), visible.maxX - panel.frame.width - 16)
        let y = visible.maxY - panel.frame.height - 12
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func findSearchField(in view: NSView?) -> NSSearchField? {
        guard let view else { return nil }
        if let searchField = view as? NSSearchField { return searchField }
        for subview in view.subviews {
            if let searchField = findSearchField(in: subview) { return searchField }
        }
        return nil
    }
}
