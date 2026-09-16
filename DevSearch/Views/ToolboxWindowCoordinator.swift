import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let toolboxFocusInput = Notification.Name("RepoGlance.toolboxFocusInput")
}

@MainActor
final class ToolboxWindowCoordinator: NSObject, NSWindowDelegate, NSToolbarDelegate {
    static let shared = ToolboxWindowCoordinator()

    private var window: NSWindow?
    private weak var model: AppModel?
    private var subscriptions = Set<AnyCancellable>()
    private let favoriteID = NSToolbarItem.Identifier("toolbox.favorite")
    private let clearID = NSToolbarItem.Identifier("toolbox.clear")

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
        guard let window, window.attachedSheet == nil else { return }
        window.makeKeyAndOrderFront(nil)
        // Finish the search field's command before transferring SwiftUI focus.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, window.isKeyWindow else { return }
            NotificationCenter.default.post(name: .toolboxFocusInput, object: nil)
            if self.model?.toolbox.selectedTool == .uuid,
               let output = self.findView(with: "toolbox-output", in: window.contentView),
               let editor = self.firstInput(in: output) {
                window.makeFirstResponder(editor)
            }
        }
    }

    private func firstInput(in view: NSView) -> NSView? {
        if view is NSTextView || view is NSTextField || view is NSDatePicker { return view }
        for child in view.subviews {
            if let input = firstInput(in: child) { return input }
        }
        return nil
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
        created.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "RepoGlanceToolboxToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        created.toolbar = toolbar
        created.contentViewController = controller
        created.minSize = NSSize(width: 760, height: 500)
        created.isReleasedWhenClosed = false
        created.tabbingMode = .disallowed
        created.animationBehavior = .utilityWindow
        created.collectionBehavior = [.moveToActiveSpace]
        created.delegate = self
        if !created.setFrameUsingName("RepoGlanceToolboxWindow") { created.center() }
        created.setFrameAutosaveName("RepoGlanceToolboxWindow")
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--compact-toolbox") {
            created.setContentSize(NSSize(width: 760, height: 500))
        }
#endif
        window = created
        model.toolbox.$selectedTool.combineLatest(model.$data)
            .receive(on: RunLoop.main)
            .sink { [weak self] tool, data in
                self?.updateToolbar(tool: tool, preferences: data.toolboxPreferences)
            }
            .store(in: &subscriptions)
        updateToolbar(tool: model.toolbox.selectedTool, preferences: model.data.toolboxPreferences)
        return created
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, favoriteID, clearID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier == favoriteID || identifier == clearID else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = identifier == favoriteID ? "收藏工具" : "清空内容"
        item.image = NSImage(systemSymbolName: identifier == favoriteID ? "star" : "trash", accessibilityDescription: item.label)
        item.toolTip = item.label
        item.target = self
        item.action = identifier == favoriteID ? #selector(toggleFavorite) : #selector(clearContent)
        return item
    }

    private func updateToolbar(tool: DeveloperToolID, preferences: ToolboxPreferences) {
        window?.title = tool.title
        window?.subtitle = "开发工具箱"
        guard let item = window?.toolbar?.items.first(where: { $0.itemIdentifier == favoriteID }) else { return }
        let favorite = preferences.favoriteToolIDs.contains(tool)
        item.label = favorite ? "取消收藏" : "收藏工具"
        item.toolTip = item.label
        item.image = NSImage(systemSymbolName: favorite ? "star.fill" : "star", accessibilityDescription: item.label)
    }

    @objc private func toggleFavorite() {
        guard let model else { return }
        model.toggleFavoriteTool(model.toolbox.selectedTool)
    }

    @objc func clearContent() {
        guard let model, let window, window.attachedSheet == nil else { return }
        let tool = model.toolbox.selectedTool
        let alert = NSAlert()
        alert.messageText = "清空\(tool.title)的内容？"
        alert.informativeText = "当前输入和结果将被清除，工具选项保持不变。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "清空内容")
        alert.buttons.last?.hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak model] response in
            guard response == .alertSecondButtonReturn, let model,
                  model.toolbox.selectedTool == tool else { return }
            model.toolbox.clearCurrentTool()
        }
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
