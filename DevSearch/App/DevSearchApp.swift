import AppKit
import SwiftUI

@MainActor
final class DevSearchApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let model else { return }
        Task { @MainActor in
            await model.start()
        }
    }
}

@main
struct DevSearchApp: App {
    @NSApplicationDelegateAdaptor(DevSearchApplicationDelegate.self)
    private var applicationDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        applicationDelegate.model = model
    }

    var body: some Scene {
        MenuBarExtra("Dev Search", systemImage: "magnifyingglass") {
            SearchPanelView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 680, minHeight: 480)
        }

        Window("编辑项目信息", id: "project-editor") {
            ProjectEditorHostView()
                .environmentObject(model)
        }
        .defaultSize(width: 560, height: 480)
        .windowResizability(.contentSize)
    }
}
