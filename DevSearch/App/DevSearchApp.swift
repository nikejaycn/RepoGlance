import AppKit
import SwiftUI

@MainActor
private enum AppDependencies {
    static let model = AppModel()
}

@MainActor
final class DevSearchApplicationDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppDependencies.model
        statusItemController = StatusItemController(model: model)
        Task { @MainActor in
            await model.start()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "RepoGlance"
        )
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "RepoGlance"
    }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = makeContextMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            SearchWindowCoordinator.shared.toggle(model: model, mode: .projects)
        }
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("打开项目搜索", action: #selector(openSearch), key: ""))
        menu.addItem(item("打开剪贴板", action: #selector(openClipboardHistory), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("立即重新扫描", action: #selector(scanNow), key: ""))

        let clipboardToggle = item(
            model.data.preferences.clipboardHistoryEnabled ? "暂停剪贴板记录" : "启用剪贴板记录",
            action: #selector(toggleClipboardHistory),
            key: ""
        )
        clipboardToggle.state = model.data.preferences.clipboardHistoryEnabled ? .on : .off
        menu.addItem(clipboardToggle)

        menu.addItem(.separator())
        menu.addItem(item("设置…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("退出 RepoGlance", action: #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func openSearch() {
        SearchWindowCoordinator.shared.show(model: model, mode: .projects)
    }

    @objc private func openClipboardHistory() {
        SearchWindowCoordinator.shared.show(model: model, mode: .clipboard)
    }

    @objc private func scanNow() {
        model.startScan()
    }

    @objc private func toggleClipboardHistory() {
        model.setClipboardHistoryEnabled(!model.data.preferences.clipboardHistoryEnabled)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct DevSearchApp: App {
    @NSApplicationDelegateAdaptor(DevSearchApplicationDelegate.self)
    private var applicationDelegate
    @StateObject private var model: AppModel

    init() {
        _model = StateObject(wrappedValue: AppDependencies.model)
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 860, minHeight: 620)
        }

        Window("编辑项目信息", id: "project-editor") {
            ProjectEditorHostView()
                .environmentObject(model)
        }
        .defaultSize(width: 560, height: 480)
        .windowResizability(.contentSize)
    }
}
