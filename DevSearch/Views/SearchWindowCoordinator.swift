import AppKit
import SwiftUI

@MainActor
final class SearchWindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = SearchWindowCoordinator()
    private var panel: NSPanel?
    var isKeyWindow: Bool { panel?.isKeyWindow == true }
    private weak var model: AppModel?

    private var isUIAcceptanceMode: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-search")
#else
        false
#endif
    }

    func toggle(model: AppModel, mode: QuickPanelMode = .projects) {
        if let panel, panel.isVisible, model.quickPanelMode == mode {
            hide()
            return
        }
        show(model: model, mode: mode)
    }

    func hide() {
        panel?.orderOut(nil)
        PreviewPanelCoordinator.shared.hideImmediately()
        model?.resetQuickPanelSession()
    }

    func show(model: AppModel, mode: QuickPanelMode = .projects) {
        self.model = model
        model.quickPanelMode = mode
        let content = SearchPanelView { [weak self] height in
            self?.resizePanel(to: height)
        }
        .environmentObject(model)
        let hosting = NSHostingView(rootView: content)
        let target: NSPanel
        if let panel {
            panel.contentView = hosting
            target = panel
        } else {
            let created = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 400),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.isOpaque = false
            created.backgroundColor = .clear
            created.hasShadow = true
            created.isMovableByWindowBackground = false
            created.hidesOnDeactivate = !isUIAcceptanceMode
            created.level = .floating
            created.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
            created.delegate = self
            panel = created
            // Assign the panel before mounting SwiftUI so SearchPanelView.onAppear
            // can immediately apply its preferred compact height.
            created.contentView = hosting
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
        guard window.attachedSheet == nil else { return }
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

    private func resizePanel(to contentHeight: CGFloat) {
        guard let panel else { return }
        let targetHeight = min(640, max(300, contentHeight))
        guard abs(panel.frame.height - targetHeight) > 0.5 else { return }

        var frame = panel.frame
        let top = frame.maxY
        frame.size.height = targetHeight
        frame.origin.y = top - targetHeight
        panel.setFrame(frame, display: true, animate: panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
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
