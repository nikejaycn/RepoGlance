import AppKit
import SwiftUI

@MainActor
final class ToolboxWindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = ToolboxWindowCoordinator()

    private var window: NSWindow?
    private weak var model: AppModel?

    var isVisible: Bool { window?.isVisible == true }
    var isKeyWindow: Bool { window?.isKeyWindow == true }

    func toggle(model: AppModel) {
        if let window, window.isVisible, window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show(model: model)
        }
    }

    func show(model: AppModel) {
        self.model = model
        let target = window ?? makeWindow(model: model)
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    func focusSearch() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        if let field = findSearchField(in: window.contentView) {
            window.makeFirstResponder(field)
        }
    }

    func focusInput() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        if let input = findView(with: "toolbox-primary-input", in: window.contentView) {
            window.makeFirstResponder(input)
        }
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === self.window else { return }
        Task { [weak model] in await model?.toolbox.windowWillClose() }
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let root = ToolboxView()
            .environmentObject(model)
            .frame(minWidth: 760, minHeight: 500)
        let controller = NSHostingController(rootView: root)
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        created.title = "RepoGlance 开发工具箱"
        created.contentViewController = controller
        created.minSize = NSSize(width: 760, height: 500)
        created.isReleasedWhenClosed = false
        created.tabbingMode = .disallowed
        created.animationBehavior = .utilityWindow
        created.collectionBehavior = [.moveToActiveSpace]
        created.delegate = self
        if !created.setFrameUsingName("RepoGlanceToolboxWindow") { created.center() }
        created.setFrameAutosaveName("RepoGlanceToolboxWindow")
        window = created
        return created
    }

    private func findSearchField(in view: NSView?) -> NSSearchField? {
        guard let view else { return nil }
        if let field = view as? NSSearchField,
           field.identifier?.rawValue == "toolbox-search-field" { return field }
        for subview in view.subviews {
            if let field = findSearchField(in: subview) { return field }
        }
        return nil
    }

    private func findView(with identifier: String, in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view.identifier?.rawValue == identifier { return view }
        for subview in view.subviews {
            if let result = findView(with: identifier, in: subview) { return result }
        }
        return nil
    }
}
