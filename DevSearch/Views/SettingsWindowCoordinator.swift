import AppKit
import SwiftUI

/// Own the settings window explicitly. SwiftUI's responder-chain settings
/// selectors aren't reliably registered for LSUIElement apps on macOS 14.
@MainActor
final class SettingsWindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowCoordinator()

    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show(model: AppModel) {
        let target = window ?? makeWindow(model: model)
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let rootView = SettingsView()
            .environmentObject(model)
            .frame(minWidth: 860, minHeight: 620)
        let hostingController = NSHostingController(rootView: rootView)
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        created.title = "RepoGlance 设置"
        created.contentViewController = hostingController
        created.minSize = NSSize(width: 860, height: 620)
        created.isReleasedWhenClosed = false
        created.tabbingMode = .disallowed
        created.animationBehavior = .utilityWindow
        created.collectionBehavior = [.moveToActiveSpace]
        created.delegate = self

        if !created.setFrameUsingName("RepoGlanceSettingsWindow") {
            created.center()
        }
        created.setFrameAutosaveName("RepoGlanceSettingsWindow")

        window = created
        return created
    }
}
