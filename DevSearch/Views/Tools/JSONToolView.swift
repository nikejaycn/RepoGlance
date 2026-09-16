import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct JSONToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("操作", selection: model.toolPreference(\.jsonAction)) {
                    ForEach(JSONToolAction.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                if prefs.jsonAction == .format {
                    Picker("缩进", selection: model.toolPreference(\.jsonIndentWidth)) {
                        Text("2 空格").tag(2)
                        Text("4 空格").tag(4)
                    }
                    .frame(width: 120)
                }
                Spacer()
            }
            HStack(spacing: 14) {
                ToolTextPane(title: "JSON 输入", text: $toolbox.jsonInput, identifier: "toolbox-primary-input") {
                    Button("使用剪贴板", systemImage: "clipboard") {
                        if let value = model.toolboxClipboardText() { toolbox.jsonInput = value }
                    }
                }
                ToolOutputPane(title: prefs.jsonAction == .validate ? "校验结果" : "结果", text: output) {
                    ToolCopyButton(text: output)
                }
            }
            if let error { ToolErrorLabel(error) }
        }
        .padding(20)
        .task(id: JSONRequest(input: toolbox.jsonInput, action: prefs.jsonAction, indent: prefs.jsonIndentWidth)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            guard !toolbox.jsonInput.isEmpty else { output = ""; error = nil; return }
            do {
                output = try JSONService.process(
                    toolbox.jsonInput,
                    action: prefs.jsonAction,
                    indentWidth: prefs.jsonIndentWidth
                )
                error = nil
            } catch {
                output = ""
                self.error = error.localizedDescription
            }
        }
    }

    private var prefs: ToolboxPreferences { model.data.toolboxPreferences }
}
