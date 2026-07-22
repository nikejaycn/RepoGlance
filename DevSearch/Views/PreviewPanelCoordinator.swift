import AppKit
import SwiftUI

private final class InteractivePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PreviewPanelCoordinator {
    static let shared = PreviewPanelCoordinator()

    private var panel: NSPanel?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var pendingAnchorRect: NSRect?
    private var keyMonitor: Any?
    private(set) var isInteractive = false

    private init() {}

    func scheduleShow(project: ProjectRecord, model: AppModel, anchorRect: NSRect? = nil) {
        hideTask?.cancel()
        showTask?.cancel()
        let delay = max(0, model.data.preferences.previewDelayMilliseconds)
        pendingAnchorRect = anchorRect
        showTask = Task { [weak self, weak model] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled, let self, let model else { return }
            self.show(project: project, model: model, anchorRect: self.pendingAnchorRect)
        }
    }

    func showImmediately(project: ProjectRecord, model: AppModel, anchorRect: NSRect? = nil) {
        hideTask?.cancel()
        showTask?.cancel()
        show(project: project, model: model, anchorRect: anchorRect)
    }

    func enter(project: ProjectRecord, model: AppModel) {
        hideTask?.cancel()
        showTask?.cancel()
        isInteractive = true
        installKeyMonitor()
        show(project: project, model: model, anchorRect: pendingAnchorRect, focusContent: true)
        panel?.becomesKeyOnlyIfNeeded = false
        panel?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel, self?.isInteractive == true else { return }
            panel.makeKey()
            panel.selectNextKeyView(nil)
        }
    }

    func returnToSearch() {
        isInteractive = false
        removeKeyMonitor()
        panel?.becomesKeyOnlyIfNeeded = true
        panel?.orderOut(nil)
        SearchWindowCoordinator.shared.restoreSearchFocus()
    }

    func scheduleHide() {
        guard !isInteractive else { return }
        showTask?.cancel()
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.hideImmediately()
        }
    }

    func cancelHide() {
        hideTask?.cancel()
    }

    func hideImmediately() {
        showTask?.cancel()
        isInteractive = false
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isInteractive, event.keyCode == 53 else { return event }
            self.returnToSearch()
            return nil
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func show(
        project: ProjectRecord,
        model: AppModel,
        anchorRect: NSRect?,
        focusContent: Bool = false
    ) {
        let content = ProjectPreviewView(
            projectID: project.id,
            initialTab: project.customDescription.isEmpty ? .readme : .description,
            focusContentOnAppear: focusContent
        )
            .environmentObject(model)
            .onHover { [weak self] hovering in
                if hovering { self?.cancelHide() }
                else { self?.scheduleHide() }
            }

        let hostingView = NSHostingView(rootView: content)
        let targetPanel: NSPanel
        if let panel {
            targetPanel = panel
            targetPanel.contentView = hostingView
        } else {
            let created = InteractivePreviewPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            created.isFloatingPanel = true
            created.becomesKeyOnlyIfNeeded = true
            created.hidesOnDeactivate = true
            created.level = .popUpMenu
            created.isOpaque = false
            created.backgroundColor = .clear
            created.hasShadow = true
            created.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
            created.animationBehavior = .utilityWindow
            created.contentView = hostingView
            panel = created
            targetPanel = created
        }

        targetPanel.setContentSize(NSSize(width: 420, height: 520))
        targetPanel.animationBehavior = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .none
            : .utilityWindow
        position(targetPanel, anchorRect: anchorRect)
        targetPanel.orderFrontRegardless()
    }

    private func position(_ previewPanel: NSPanel, anchorRect: NSRect?) {
        let anchor = NSApp.keyWindow ?? NSApp.windows.first {
            $0.isVisible && $0 !== previewPanel && !($0 is NSPanel)
        }
        guard let anchor, let screen = anchor.screen ?? NSScreen.main else { return }

        let origin = PreviewPanelPlacement.origin(
            anchorWindowFrame: anchor.frame,
            contentAnchorRect: anchorRect,
            panelSize: previewPanel.frame.size,
            visibleScreenFrame: screen.visibleFrame
        )
        previewPanel.setFrameOrigin(origin)
    }
}

enum PreviewPanelPlacement {
    static func origin(
        anchorWindowFrame: NSRect,
        contentAnchorRect: NSRect?,
        panelSize: NSSize,
        visibleScreenFrame: NSRect
    ) -> NSPoint {
        let visible = visibleScreenFrame.insetBy(dx: 16, dy: 16)
        let placementAnchor = contentAnchorRect ?? anchorWindowFrame
        let rightX = anchorWindowFrame.maxX + 8
        let leftX = anchorWindowFrame.minX - panelSize.width - 8
        let x: CGFloat
        if rightX + panelSize.width <= visible.maxX { x = rightX }
        else if leftX >= visible.minX { x = leftX }
        else { x = max(visible.minX, min(rightX, visible.maxX - panelSize.width)) }

        let proposedY = placementAnchor.midY - panelSize.height / 2
        let y = max(visible.minY, min(proposedY, visible.maxY - panelSize.height))
        return NSPoint(x: x, y: y)
    }
}
