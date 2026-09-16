import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct QRCodeToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var image: CGImage?
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                ToolSectionHeader("内容") {
                    Button("使用剪贴板", systemImage: "clipboard") {
                        if let text = model.toolboxClipboardText() { toolbox.qrText = text }
                    }
                }
                ToolTextEditor(text: $toolbox.qrText, identifier: "toolbox-primary-input", label: "二维码内容")

                VStack(alignment: .leading, spacing: 8) {
                    Picker("纠错等级", selection: qrCorrectionBinding) {
                        ForEach(QRCorrectionLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("尺寸", selection: qrSizeBinding) {
                        Text("256 px").tag(256)
                        Text("512 px").tag(512)
                        Text("1024 px").tag(1024)
                    }
                }
                Text("二维码周围保留空白边距，便于扫描。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                GroupBox("预览") {
                    ZStack {
                        if let image {
                            Image(decorative: image, scale: 1, orientation: .up)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(16)
                                .background(.white)
                                .accessibilityLabel("由当前文本生成的二维码")
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode").font(.largeTitle)
                                Text(toolbox.qrText.isEmpty ? "输入内容以生成二维码" : "无法生成二维码")
                                    .font(.callout)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let error { ToolErrorLabel(error) }

                HStack {
                    Button(copied ? "已复制" : "复制图片", systemImage: copied ? "checkmark" : "doc.on.doc") {
                        guard let image else { return }
                        model.copyToolboxImage(image)
                        showCopied()
                    }
                    .disabled(image == nil)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    Button("导出 PNG…", systemImage: "square.and.arrow.down") { exportPNG() }
                        .disabled(image == nil)
                }
            }
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)
        }
        .padding(20)
        .task(id: QRRequest(text: toolbox.qrText, level: preferences.qrCorrectionLevel, size: preferences.qrOutputSize)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            guard !toolbox.qrText.isEmpty else { image = nil; error = nil; return }
            do {
                image = try QRCodeService.generate(
                    text: toolbox.qrText,
                    correctionLevel: preferences.qrCorrectionLevel,
                    size: preferences.qrOutputSize
                )
                error = nil
            } catch {
                image = nil
                self.error = error.localizedDescription
            }
        }
    }

    private var preferences: ToolboxPreferences { model.data.toolboxPreferences }
    private var qrCorrectionBinding: Binding<QRCorrectionLevel> { model.toolPreference(\.qrCorrectionLevel) }
    private var qrSizeBinding: Binding<Int> { model.toolPreference(\.qrOutputSize) }


    private func exportPNG() {
        guard let image, let data = QRCodeService.pngData(from: image) else { return }
        let panel = NSSavePanel()
        panel.title = "导出二维码"
        panel.nameFieldStringValue = "RepoGlance-QRCode.png"
        panel.allowedContentTypes = [.png]
        Task { @MainActor in
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }
            do { try data.write(to: url, options: .atomic) }
            catch { self.error = "导出失败：\(error.localizedDescription)" }
        }
    }

    private func showCopied() {
        copied = true
        Task {
            try? await Task.sleep(for: .milliseconds(1_500))
            copied = false
        }
    }
}
