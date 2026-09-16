import AppKit

/// Present window-owned tasks as sheets. A menu-bar command with no window
/// can still use the standard standalone panel.
@MainActor
enum NativePresentation {
    static func present(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        let parent = NSApp.keyWindow
        return await withCheckedContinuation { continuation in
            if let parent, parent.attachedSheet == nil {
                panel.beginSheetModal(for: parent) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
    }

    static func present(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        guard let parent = NSApp.keyWindow, parent.attachedSheet == nil else {
            return alert.runModal()
        }
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: parent) { continuation.resume(returning: $0) }
        }
    }
}
