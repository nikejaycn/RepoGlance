import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EncodingToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("格式", selection: model.toolPreference(\.encodingFormat)) {
                    ForEach(EncodingFormat.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 220)
                Picker("方向", selection: model.toolPreference(\.encodingDirection)) {
                    ForEach(TransformDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
                Button("交换", systemImage: "arrow.left.arrow.right") { swap() }
                    .disabled(output.isEmpty)
            }

            HStack(spacing: 14) {
                ToolTextPane(title: "输入", text: $toolbox.encodingInput, identifier: "toolbox-primary-input") {
                    Button("使用剪贴板", systemImage: "clipboard") {
                        if let value = model.toolboxClipboardText() { toolbox.encodingInput = value }
                    }
                }
                ToolOutputPane(title: "输出", text: output) {
                    ToolCopyButton(text: output)
                }
            }
            if let error { ToolErrorLabel(error) }
            HStack {
                Text("所有文本按 UTF-8 处理；URL 模式遵循 RFC 3986 非保留字符。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .task(id: EncodingRequest(input: toolbox.encodingInput, format: prefs.encodingFormat, direction: prefs.encodingDirection)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            guard !toolbox.encodingInput.isEmpty else { output = ""; error = nil; return }
            do {
                output = try EncodingService.transform(
                    toolbox.encodingInput,
                    format: prefs.encodingFormat,
                    direction: prefs.encodingDirection
                )
                error = nil
            } catch {
                output = ""
                self.error = error.localizedDescription
            }
        }
    }

    private var prefs: ToolboxPreferences { model.data.toolboxPreferences }


    private func swap() {
        toolbox.encodingInput = output
        var preferences = prefs
        preferences.encodingDirection = preferences.encodingDirection.opposite
        model.updateToolboxPreferences(preferences)
    }
}
