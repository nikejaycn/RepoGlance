import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct UUIDToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("数量", selection: model.toolPreference(\.uuidCount)) {
                    ForEach([1, 5, 10, 20], id: \.self) { Text("\($0) 个").tag($0) }
                }
                .frame(width: 130)
                Toggle("大写", isOn: model.toolPreference(\.uuidUppercase))
                Spacer()
                Button("重新生成", systemImage: "arrow.clockwise", action: generate)
                    .keyboardShortcut(.return, modifiers: .command)
            }

            ToolOutputPane(title: "UUID v4", text: displayedResults.joined(separator: "\n")) {
                ToolCopyButton(text: displayedResults.joined(separator: "\n"), title: "复制全部")
            }

            Text("每次重新生成都会替换当前结果，不保留生成历史。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .task { if toolbox.uuidResults.isEmpty { generate() } }
    }

    private func generate() {
        toolbox.uuidResults = UUIDService.generate(
            count: model.data.toolboxPreferences.uuidCount,
            uppercase: model.data.toolboxPreferences.uuidUppercase
        )
    }

    private var displayedResults: [String] {
        toolbox.uuidResults.map {
            model.data.toolboxPreferences.uuidUppercase ? $0.uppercased() : $0.lowercased()
        }
    }

}
