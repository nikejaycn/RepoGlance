import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HashToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("算法", selection: model.toolPreference(\.hashAlgorithm)) {
                    ForEach(HashAlgorithm.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 180)
                Toggle("大写 Hex", isOn: model.toolPreference(\.hashUppercase))
                Spacer()
            }
            HStack(spacing: 14) {
                ToolTextPane(title: "文本输入", text: $toolbox.hashInput, identifier: "toolbox-primary-input") {
                    Button("使用剪贴板", systemImage: "clipboard") {
                        if let value = model.toolboxClipboardText() { toolbox.hashInput = value }
                    }
                }
                ToolOutputPane(title: prefs.hashAlgorithm.title, text: output) {
                    ToolCopyButton(text: output)
                }
            }
            if prefs.hashAlgorithm.isLegacy {
                Label("\(prefs.hashAlgorithm.title) 仅适合兼容或校验，不适合密码等安全用途。", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .task(id: HashRequest(input: toolbox.hashInput, algorithm: prefs.hashAlgorithm, uppercase: prefs.hashUppercase)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            output = toolbox.hashInput.isEmpty ? "" : HashService.digest(
                toolbox.hashInput,
                algorithm: prefs.hashAlgorithm,
                uppercase: prefs.hashUppercase
            )
        }
    }

    private var prefs: ToolboxPreferences { model.data.toolboxPreferences }
}
