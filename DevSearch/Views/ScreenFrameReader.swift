import AppKit
import SwiftUI

struct ScreenFrameReader: NSViewRepresentable {
    let onChange: @MainActor (NSRect) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onFrameChange = onChange
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.onFrameChange = onChange
        view.reportFrame()
    }

    @MainActor
    final class TrackingView: NSView {
        var onFrameChange: (@MainActor (NSRect) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrame()
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard let window else { return }
            let windowRect = convert(bounds, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            DispatchQueue.main.async { [weak self] in self?.onFrameChange?(screenRect) }
        }
    }
}
