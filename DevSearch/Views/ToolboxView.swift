import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolboxView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ToolboxShell(toolbox: model.toolbox)
            .environmentObject(model)
    }
}

private struct ToolboxShell: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 224)
                .background(ToolboxSidebarMaterial())
            Divider()
            workbench
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("开发工具箱", isPresented: persistenceErrorBinding) {
            Button("好") { toolbox.persistenceError = nil }
        } message: {
            Text(toolbox.persistenceError ?? "")
        }
        .background(ToolboxKeyboardMonitor())
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            NativeSearchField(
                text: $toolbox.searchQuery,
                placeholder: "搜索工具…",
                focusOnAppear: false,
                usesSidebarAppearance: true,
                preferredHeight: 28,
                accessibilityIdentifier: "toolbox-search-field"
            )
            .frame(height: 28)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            List(selection: selectionBinding) {
                if toolbox.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !favoriteTools.isEmpty {
                        Section("收藏") {
                            ForEach(favoriteTools) { tool in toolRow(tool) }
                        }
                    }
                    if !recentTools.isEmpty {
                        Section("最近使用") {
                            ForEach(recentTools) { tool in toolRow(tool) }
                        }
                    }
                    ForEach(DeveloperToolCategory.allCases) { category in
                        Section(category.title) {
                            ForEach(DeveloperToolID.allCases.filter { $0.category == category }) { tool in
                                toolRow(tool)
                            }
                        }
                    }
                } else {
                    Section("搜索结果") {
                        ForEach(filteredTools) { tool in toolRow(tool) }
                    }
                }
            }
            .listStyle(.sidebar)
            .overlay {
                if filteredTools.isEmpty {
                    ContentUnavailableView.search(text: toolbox.searchQuery)
                }
            }
            .accessibilityIdentifier("toolbox-sidebar")
        }
    }

    private var workbench: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: toolbox.selectedTool.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolbox.selectedTool.title)
                        .font(.title2.weight(.semibold))
                    Text(toolbox.selectedTool.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if toolbox.oversizedTools.contains(toolbox.selectedTool) {
                    Label("内容超过 1 MB，本次不会恢复", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button {
                    model.toggleFavoriteTool(toolbox.selectedTool)
                } label: {
                    Image(systemName: isFavorite(toolbox.selectedTool) ? "star.fill" : "star")
                }
                .buttonStyle(.borderless)
                .help(isFavorite(toolbox.selectedTool) ? "取消收藏" : "收藏工具")
                .accessibilityLabel(isFavorite(toolbox.selectedTool) ? "取消收藏" : "收藏工具")
                Button("清空", systemImage: "trash", action: toolbox.clearCurrentTool)
                    .keyboardShortcut("k", modifiers: .command)
            }
            .padding(.horizontal, 20)
            .frame(height: 72)

            Divider()

            Group {
                switch toolbox.selectedTool {
                case .qrCode: QRCodeToolView(toolbox: toolbox)
                case .encoding: EncodingToolView(toolbox: toolbox)
                case .timestamp: TimestampToolView(toolbox: toolbox)
                case .json: JSONToolView(toolbox: toolbox)
                case .uuid: UUIDToolView(toolbox: toolbox)
                case .hash: HashToolView(toolbox: toolbox)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func toolRow(_ tool: DeveloperToolID) -> some View {
        Label(tool.title, systemImage: tool.systemImage)
            .tag(tool)
            .contextMenu {
                Button(isFavorite(tool) ? "取消收藏" : "收藏") {
                    model.toggleFavoriteTool(tool)
                }
            }
    }

    private var selectionBinding: Binding<DeveloperToolID?> {
        Binding(
            get: { toolbox.selectedTool },
            set: { if let tool = $0 { model.selectTool(tool) } }
        )
    }

    private var favoriteTools: [DeveloperToolID] {
        DeveloperToolID.allCases.filter { model.data.toolboxPreferences.favoriteToolIDs.contains($0) }
    }

    private var recentTools: [DeveloperToolID] {
        model.data.toolboxPreferences.recentToolIDs.filter {
            !model.data.toolboxPreferences.favoriteToolIDs.contains($0)
        }
    }

    private var filteredTools: [DeveloperToolID] {
        DeveloperToolID.allCases.filter { $0.matches(toolbox.searchQuery) }
    }

    private func isFavorite(_ tool: DeveloperToolID) -> Bool {
        model.data.toolboxPreferences.favoriteToolIDs.contains(tool)
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { toolbox.persistenceError != nil },
            set: { if !$0 { toolbox.persistenceError = nil } }
        )
    }
}

private struct QRCodeToolView: View {
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
                ToolTextEditor(text: $toolbox.qrText, identifier: "toolbox-primary-input")

                HStack {
                    Picker("纠错等级", selection: qrCorrectionBinding) {
                        ForEach(QRCorrectionLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("尺寸", selection: qrSizeBinding) {
                        Text("256 px").tag(256)
                        Text("512 px").tag(512)
                        Text("1024 px").tag(1024)
                    }
                }
                Text("首期使用标准黑白样式，并保留二维码规范静区。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                GroupBox("预览") {
                    ZStack {
                        Color.white
                        if let image {
                            Image(decorative: image, scale: 1, orientation: .up)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(16)
                                .accessibilityLabel("由当前文本生成的二维码")
                        } else {
                            ContentUnavailableView(
                                toolbox.qrText.isEmpty ? "输入内容以生成二维码" : "无法生成二维码",
                                systemImage: "qrcode"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
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
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
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
    private var qrCorrectionBinding: Binding<QRCorrectionLevel> { toolboxPreference(\.qrCorrectionLevel) }
    private var qrSizeBinding: Binding<Int> { toolboxPreference(\.qrOutputSize) }

    private func toolboxPreference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { model.data.toolboxPreferences[keyPath: path] },
            set: { value in
                var preferences = model.data.toolboxPreferences
                preferences[keyPath: path] = value
                model.updateToolboxPreferences(preferences)
                Task { await toolbox.persistNow() }
            }
        )
    }

    private func exportPNG() {
        guard let image, let data = QRCodeService.pngData(from: image) else { return }
        let panel = NSSavePanel()
        panel.title = "导出二维码"
        panel.nameFieldStringValue = "RepoGlance-QRCode.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url, options: .atomic) }
        catch { self.error = "导出失败：\(error.localizedDescription)" }
    }

    private func showCopied() {
        copied = true
        Task {
            try? await Task.sleep(for: .milliseconds(1_500))
            copied = false
        }
    }
}

private struct EncodingToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("格式", selection: preference(\.encodingFormat)) {
                    ForEach(EncodingFormat.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 220)
                Picker("方向", selection: preference(\.encodingDirection)) {
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

    private func preference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = model.data.toolboxPreferences
            preferences[keyPath: path] = value
            model.updateToolboxPreferences(preferences)
            Task { await toolbox.persistNow() }
        })
    }

    private func swap() {
        toolbox.encodingInput = output
        var preferences = prefs
        preferences.encodingDirection = preferences.encodingDirection.opposite
        model.updateToolboxPreferences(preferences)
    }
}

private struct TimestampToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var result: TimestampConversion?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("转换方向", selection: preference(\.timestampDirection)) {
                ForEach(TimestampDirection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            GroupBox("输入") {
                VStack(alignment: .leading, spacing: 12) {
                    if prefs.timestampDirection == .timestampToDate {
                        HStack {
                            TextField("例如 1723723200", text: $toolbox.timestampInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.body.monospaced())
                                .accessibilityIdentifier("toolbox-primary-input")
                            Picker("单位", selection: preference(\.timestampUnit)) {
                                ForEach(TimestampUnit.allCases) { Text($0.title).tag($0) }
                            }
                            .frame(width: 150)
                            Button("使用剪贴板") {
                                if let value = model.toolboxClipboardText() { toolbox.timestampInput = value }
                            }
                        }
                    } else {
                        DatePicker(
                            "日期与时间",
                            selection: $toolbox.timestampDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .accessibilityIdentifier("toolbox-primary-input")
                    }
                    HStack {
                        Picker("时区", selection: preference(\.timestampTimeZoneIdentifier)) {
                            ForEach(timeZoneIdentifiers, id: \.self) { identifier in
                                Text(timeZoneName(identifier)).tag(identifier)
                            }
                        }
                        .frame(maxWidth: 320)
                        Button("使用当前时间") {
                            if prefs.timestampDirection == .timestampToDate {
                                toolbox.timestampInput = String(Int(Date().timeIntervalSince1970))
                            } else {
                                toolbox.timestampDate = Date()
                            }
                        }
                    }
                }
                .padding(4)
            }

            if let error { ToolErrorLabel(error) }

            GroupBox("换算结果") {
                VStack(spacing: 0) {
                    TimestampResultRow(title: "Unix 秒", value: result?.seconds ?? "—")
                    Divider()
                    TimestampResultRow(title: "Unix 毫秒", value: result?.milliseconds ?? "—")
                    Divider()
                    TimestampResultRow(title: "ISO 8601", value: result?.iso8601 ?? "—")
                    Divider()
                    TimestampResultRow(title: "可读日期", value: result?.readable ?? "—")
                }
            }
            Spacer()
        }
        .padding(20)
        .task(id: TimestampRequest(
            input: toolbox.timestampInput,
            date: toolbox.timestampDate,
            direction: prefs.timestampDirection,
            unit: prefs.timestampUnit,
            timeZoneIdentifier: prefs.timestampTimeZoneIdentifier
        )) {
            let timeZone = TimeZone(identifier: prefs.timestampTimeZoneIdentifier) ?? .current
            do {
                if prefs.timestampDirection == .timestampToDate {
                    guard !toolbox.timestampInput.isEmpty else { result = nil; error = nil; return }
                    result = try TimestampService.convert(
                        timestamp: toolbox.timestampInput,
                        unit: prefs.timestampUnit,
                        timeZone: timeZone
                    )
                } else {
                    result = TimestampService.convert(date: toolbox.timestampDate, timeZone: timeZone)
                }
                error = nil
            } catch {
                result = nil
                self.error = error.localizedDescription
            }
        }
    }

    private var prefs: ToolboxPreferences { model.data.toolboxPreferences }
    private var timeZoneIdentifiers: [String] {
        let values = [TimeZone.current.identifier, "UTC", "Asia/Shanghai", "America/Los_Angeles", "Europe/London"]
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func timeZoneName(_ identifier: String) -> String {
        if identifier == TimeZone.current.identifier { return "本地（\(identifier)）" }
        return identifier
    }

    private func preference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = model.data.toolboxPreferences
            preferences[keyPath: path] = value
            model.updateToolboxPreferences(preferences)
            Task { await toolbox.persistNow() }
        })
    }
}

private struct JSONToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("操作", selection: preference(\.jsonAction)) {
                    ForEach(JSONToolAction.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                if prefs.jsonAction == .format {
                    Picker("缩进", selection: preference(\.jsonIndentWidth)) {
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
    private func preference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = model.data.toolboxPreferences
            preferences[keyPath: path] = value
            model.updateToolboxPreferences(preferences)
            Task { await toolbox.persistNow() }
        })
    }
}

private struct UUIDToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("数量", selection: preference(\.uuidCount)) {
                    ForEach([1, 5, 10, 20], id: \.self) { Text("\($0) 个").tag($0) }
                }
                .frame(width: 130)
                Toggle("大写", isOn: preference(\.uuidUppercase))
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
        .onAppear { if toolbox.uuidResults.isEmpty { generate() } }
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

    private func preference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = model.data.toolboxPreferences
            preferences[keyPath: path] = value
            model.updateToolboxPreferences(preferences)
            Task { await toolbox.persistNow() }
        })
    }
}

private struct HashToolView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var toolbox: ToolboxModel
    @State private var output = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Picker("算法", selection: preference(\.hashAlgorithm)) {
                    ForEach(HashAlgorithm.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 180)
                Toggle("大写 Hex", isOn: preference(\.hashUppercase))
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
    private func preference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = model.data.toolboxPreferences
            preferences[keyPath: path] = value
            model.updateToolboxPreferences(preferences)
            Task { await toolbox.persistNow() }
        })
    }
}

private struct ToolTextPane<Trailing: View>: View {
    let title: String
    @Binding var text: String
    let identifier: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToolSectionHeader(title, trailing: trailing)
            ToolTextEditor(text: $text, identifier: identifier)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ToolOutputPane<Trailing: View>: View {
    let title: String
    let text: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToolSectionHeader(title, trailing: trailing)
            ReadOnlyTextView(text: text)
                .accessibilityIdentifier("toolbox-output")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ToolSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            trailing()
                .controlSize(.small)
        }
    }
}

private struct ToolTextEditor: View {
    @Binding var text: String
    let identifier: String

    var body: some View {
        TextEditor(text: $text)
            .font(.body.monospaced())
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 0.5)
            }
            .accessibilityIdentifier(identifier)
    }
}

private struct ReadOnlyTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        scrollView.identifier = NSUserInterfaceItemIdentifier("toolbox-output")
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }
}

private struct ToolCopyButton: View {
    @EnvironmentObject private var model: AppModel
    let text: String
    var title = "复制"
    @State private var copied = false

    var body: some View {
        Button(copied ? "已复制" : title, systemImage: copied ? "checkmark" : "doc.on.doc") {
            model.copyToolboxText(text)
            copied = true
            Task {
                try? await Task.sleep(for: .milliseconds(1_500))
                copied = false
            }
        }
        .disabled(text.isEmpty)
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }
}

private struct TimestampResultRow: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let value: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
            Spacer()
            Button {
                model.copyToolboxText(value)
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1_500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(value == "—")
            .help("复制 \(title)")
            .accessibilityLabel("复制 \(title)")
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
    }
}

private struct ToolErrorLabel: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("toolbox-error")
    }
}

private struct ToolboxSidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .sidebar
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
    }
}

private struct ToolboxKeyboardMonitor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?

        func start() {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard ToolboxWindowCoordinator.shared.isKeyWindow else { return event }
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let shortcutModifiers = modifiers.intersection([.command, .option, .control, .shift])
                guard shortcutModifiers == .command else { return event }
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "f", "1":
                    ToolboxWindowCoordinator.shared.focusSearch()
                    return nil
                case "2":
                    ToolboxWindowCoordinator.shared.focusInput()
                    return nil
                default:
                    return event
                }
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}

private struct QRRequest: Hashable { let text: String; let level: QRCorrectionLevel; let size: Int }
private struct EncodingRequest: Hashable { let input: String; let format: EncodingFormat; let direction: TransformDirection }
private struct TimestampRequest: Hashable {
    let input: String
    let date: Date
    let direction: TimestampDirection
    let unit: TimestampUnit
    let timeZoneIdentifier: String
}
private struct JSONRequest: Hashable { let input: String; let action: JSONToolAction; let indent: Int }
private struct HashRequest: Hashable { let input: String; let algorithm: HashAlgorithm; let uppercase: Bool }
