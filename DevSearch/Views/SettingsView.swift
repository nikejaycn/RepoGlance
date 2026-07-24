import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SettingsSection = .general
    @State private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                NativeSearchField(
                    text: $query,
                    placeholder: "搜索设置…",
                    focusOnAppear: false,
                    usesSidebarAppearance: true,
                    preferredHeight: 28,
                    accessibilityIdentifier: "settings-search-field"
                )
                .frame(height: 28)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                List(filteredSections, selection: $selection) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .overlay {
                    if filteredSections.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .frame(width: 218)
            .background(SidebarMaterialBackground())

            Divider()

            Group {
                switch selection {
                case .general: GeneralSettingsView()
                case .sources: ScanRootsSettingsView()
                case .opening: EditorSettingsView()
                case .clipboard: ClipboardSettingsView()
                case .data: IndexSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(selection.title)
        }
        .onChange(of: query) { _, _ in
            guard !filteredSections.contains(selection), let first = filteredSections.first else { return }
            selection = first
        }
    }

    private var filteredSections: [SettingsSection] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter { $0.matches(needle) }
    }
}

private struct SidebarMaterialBackground: NSViewRepresentable {
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

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case sources
    case opening
    case clipboard
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .sources: "项目来源"
        case .opening: "打开方式"
        case .clipboard: "剪贴板"
        case .data: "数据与关于"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .sources: "folder"
        case .opening: "command"
        case .clipboard: "clipboard"
        case .data: "externaldrive"
        }
    }

    func matches(_ query: String) -> Bool {
        let searchableText: String
        switch self {
        case .general:
            searchableText = "通用 登录 启动 快捷键 搜索面板 预览 扫描"
        case .sources:
            searchableText = "项目来源 扫描目录 隐藏目录 深度 忽略路径 排除项目"
        case .opening:
            searchableText = "打开方式 编辑器 Visual Studio Code Xcode Cursor Zed 终端"
        case .clipboard:
            searchableText = "剪贴板 历史 保留 快捷键 清空 本机"
        case .data:
            searchableText = "数据 关于 项目总数 顶层仓库 嵌套仓库 索引 导入 导出 版本"
        }
        return searchableText.localizedCaseInsensitiveContains(query)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("启动与行为") {
                Toggle("登录时启动", isOn: launchAtLoginBinding)
                Toggle("启用全局快捷键", isOn: preferenceBinding(\.globalShortcutEnabled))
                Toggle("打开项目后关闭搜索面板", isOn: preferenceBinding(\.closeAfterOpening))
            }

            Section("搜索与预览") {
                Picker("快捷键", selection: preferenceBinding(\.globalShortcut)) {
                    ForEach(GlobalShortcut.allCases.filter { $0 != .optionShiftSpace }) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
                .disabled(!model.data.preferences.globalShortcutEnabled)

                Picker("预览等待时间", selection: previewDelayBinding) {
                    Text("快速（250 ms）").tag(250)
                    Text("标准（400 ms）").tag(400)
                    Text("较慢（600 ms）").tag(600)
                }
            }

            Section("索引更新") {
                Picker("定时兜底扫描", selection: preferenceBinding(\.automaticScanIntervalMinutes)) {
                    Text("关闭（仍监听文件变化）").tag(0)
                    Text("每 5 分钟").tag(5)
                    Text("每 15 分钟").tag(15)
                    Text("每 30 分钟").tag(30)
                    Text("每 60 分钟").tag(60)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var previewDelayBinding: Binding<Int> {
        Binding(
            get: { model.data.preferences.previewDelayMilliseconds },
            set: { value in
                var preferences = model.data.preferences
                preferences.previewDelayMilliseconds = value
                model.updatePreferences(preferences)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.data.preferences.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private func preferenceBinding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { model.data.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = model.data.preferences
                preferences[keyPath: keyPath] = value
                model.updatePreferences(preferences)
            }
        )
    }
}

private struct ClipboardSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("剪贴板历史") {
                Toggle("记录文本剪贴板历史", isOn: enabledBinding)
                Picker("最多保留", selection: limitBinding) {
                    Text("50 条").tag(50)
                    Text("100 条").tag(100)
                    Text("200 条").tag(200)
                    Text("500 条").tag(500)
                }
                LabeledContent("专用快捷键", value: "⌥ ⇧ Space")
                LabeledContent("当前记录", value: "\(model.data.clipboardItems.count) 条")

                HStack {
                    Button("打开剪贴板") {
                        SearchWindowCoordinator.shared.show(model: model, mode: .clipboard)
                    }
                    Button("清空历史…", role: .destructive) { confirmClear = true }
                        .disabled(model.data.clipboardItems.isEmpty)
                }
            }

            Section("隐私") {
                Label {
                    Text("仅记录启用后新复制的纯文本，数据只保存在本机。标记为临时、隐藏或密码内容的剪贴板条目不会被记录；单条文本最大 100 KB。")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("清空剪贴板历史？", isPresented: $confirmClear) {
            Button("清空历史", role: .destructive) { model.clearClipboardHistory() }
            Button("取消", role: .cancel) {}
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.data.preferences.clipboardHistoryEnabled },
            set: { model.setClipboardHistoryEnabled($0) }
        )
    }

    private var limitBinding: Binding<Int> {
        Binding(
            get: { model.data.preferences.clipboardHistoryLimit },
            set: { value in
                var preferences = model.data.preferences
                preferences.clipboardHistoryLimit = value
                model.updatePreferences(preferences)
            }
        )
    }
}

private struct ScanRootsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var rootPendingRemoval: ScanRoot?

    var body: some View {
        Form {
            Section("扫描目录") {
                if model.data.scanRoots.isEmpty {
                    ContentUnavailableView {
                        Label("没有扫描目录", systemImage: "folder.badge.plus")
                    } description: {
                        Text("添加一个或多个开发目录后，RepoGlance 会自动发现其中的 Git 仓库。")
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ForEach(model.data.scanRoots) { root in
                        DisclosureGroup {
                            Toggle("扫描隐藏目录", isOn: rootOptionBinding(root, keyPath: \.scanHiddenDirectories))
                            Stepper(
                                "最大扫描深度：\(currentRoot(root).maximumDepth)",
                                value: rootOptionBinding(root, keyPath: \.maximumDepth),
                                in: 1...128
                            )
                            TextField("忽略目录名（逗号分隔）", text: ignoredNamesBinding(root))
                                .onSubmit { model.startScan() }
                            TextField("忽略相对路径（逗号分隔）", text: ignoredPathsBinding(root))
                                .help("相对于扫描目录，例如 archive/legacy；同时忽略其下所有内容")
                                .onSubmit { model.startScan() }
                        } label: {
                            HStack {
                                Toggle("", isOn: rootEnabledBinding(root))
                                    .labelsHidden()
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(URL(fileURLWithPath: root.canonicalPath).lastPathComponent)
                                    Text(root.displayPath)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(root.lastScanAt.map { "上次扫描：\($0.formatted())" } ?? "尚未扫描")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(projectCount(for: root)) 个项目 · \(statusText(for: root))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { rootPendingRemoval = root } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("移除扫描目录 \(root.displayPath)")
                            }
                        }
                    }
                }

                Button("添加目录…", systemImage: "plus") {
                    model.chooseAndAddScanRoot()
                }
            }

            if !model.scanIssues.isEmpty {
                Section("扫描问题") {
                    ForEach(model.scanIssues) { issue in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scanIssueTitle(issue))
                                Text(issue.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let root = model.data.scanRoots.first(where: { $0.canonicalPath == issue.rootPath }) {
                                Button("重新选择…") { model.chooseReplacement(for: root) }
                            }
                        }
                    }
                }
            }

            Section("已排除项目") {
                if model.data.exclusionRules.isEmpty {
                    Text("没有排除规则").foregroundStyle(.secondary)
                } else {
                    ForEach(model.data.exclusionRules) { rule in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(URL(fileURLWithPath: rule.canonicalPath).lastPathComponent)
                                Text(rule.canonicalPath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(rule.includesDescendants ? "包含子项目" : "仅当前项目")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("恢复") { model.restoreExclusion(rule) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("移除扫描目录？", isPresented: removalDialogBinding) {
            if let root = rootPendingRemoval {
                Button("移除并保留项目说明") { model.removeScanRoot(root); rootPendingRemoval = nil }
                Button("同时删除项目说明", role: .destructive) {
                    model.removeScanRoot(root, removeMetadata: true)
                    rootPendingRemoval = nil
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("默认会保留别名、说明、标签和收藏，以便以后重新添加目录。")
        }
    }

    private func rootEnabledBinding(_ root: ScanRoot) -> Binding<Bool> {
        Binding(
            get: { model.data.scanRoots.first(where: { $0.id == root.id })?.isEnabled ?? false },
            set: { enabled in
                var updated = root
                updated.isEnabled = enabled
                model.updateScanRoot(updated)
                model.startScan()
            }
        )
    }

    private func currentRoot(_ root: ScanRoot) -> ScanRoot {
        model.data.scanRoots.first(where: { $0.id == root.id }) ?? root
    }

    private func projectCount(for root: ScanRoot) -> Int {
        model.data.projects.filter { $0.scanRootPath == root.canonicalPath }.count
    }

    private func statusText(for root: ScanRoot) -> String {
        guard currentRoot(root).isEnabled else { return "已暂停" }
        if model.scanIssues.contains(where: { $0.rootPath == root.canonicalPath && $0.kind == .rootUnavailable }) {
            return "目录不可用"
        }
        if model.scanIssues.contains(where: { $0.rootPath == root.canonicalPath }) {
            return "部分读取失败"
        }
        if model.isScanning { return "扫描中" }
        return root.lastScanAt == nil ? "等待扫描" : "正常"
    }

    private func rootOptionBinding<Value>(_ root: ScanRoot, keyPath: WritableKeyPath<ScanRoot, Value>) -> Binding<Value> {
        Binding(
            get: { currentRoot(root)[keyPath: keyPath] },
            set: { value in
                var updated = currentRoot(root)
                updated[keyPath: keyPath] = value
                model.updateScanRoot(updated)
                model.startScan()
            }
        )
    }

    private func ignoredNamesBinding(_ root: ScanRoot) -> Binding<String> {
        Binding(
            get: { currentRoot(root).ignoredDirectoryNames.sorted().joined(separator: ", ") },
            set: { value in
                var updated = currentRoot(root)
                updated.ignoredDirectoryNames = Set(value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })
                model.updateScanRoot(updated)
            }
        )
    }

    private func ignoredPathsBinding(_ root: ScanRoot) -> Binding<String> {
        Binding(
            get: { currentRoot(root).ignoredRelativePaths.sorted().joined(separator: ", ") },
            set: { value in
                var updated = currentRoot(root)
                updated.ignoredRelativePaths = Set(value.split(separator: ",").compactMap { rawValue in
                    let path = rawValue
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\", with: "/")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    guard !path.isEmpty, !path.split(separator: "/").contains("..") else { return nil }
                    return path
                })
                model.updateScanRoot(updated)
            }
        )
    }

    private var removalDialogBinding: Binding<Bool> {
        Binding(
            get: { rootPendingRemoval != nil },
            set: { if !$0 { rootPendingRemoval = nil } }
        )
    }

    private func scanIssueTitle(_ issue: ScanIssue) -> String {
        switch issue.kind {
        case .rootUnavailable: "扫描目录不可用"
        case .permissionDenied: "没有目录访问权限"
        case .enumerationFailed: "部分目录读取失败"
        }
    }
}

private struct EditorSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("默认打开方式") {
                Picker("全局默认编辑器", selection: defaultEditorBinding) {
                    Text("未选择").tag(String?.none)
                    ForEach(model.data.editors) { editor in
                        Text(editor.name).tag(Optional(editor.bundleIdentifier))
                    }
                }
                Picker("终端应用", selection: terminalBinding) {
                    Text("终端").tag("com.apple.Terminal")
                    Text("iTerm").tag("com.googlecode.iterm2")
                }
            }

            Section("已发现的编辑器") {
                if model.data.editors.isEmpty {
                    ContentUnavailableView(
                        "没有发现支持的编辑器",
                        systemImage: "app.dashed"
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ForEach(model.data.editors) { editor in
                        HStack {
                            LabeledContent(editor.name) {
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(editor.applicationPath ?? "不可用")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    if editor.applicationPath == nil {
                                        Label("编辑器不可用", systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            if editor.isManuallyAdded {
                                Button(role: .destructive) { model.removeEditor(editor) } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("移除编辑器 \(editor.name)")
                            }
                        }
                    }
                }

                Button("添加其他应用…", systemImage: "plus") {
                    model.chooseAndAddEditor()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var defaultEditorBinding: Binding<String?> {
        Binding(
            get: { model.data.preferences.defaultEditorBundleIdentifier },
            set: { model.setDefaultEditor($0) }
        )
    }

    private var terminalBinding: Binding<String> {
        Binding(
            get: { model.data.preferences.terminalBundleIdentifier },
            set: { value in
                var preferences = model.data.preferences
                preferences.terminalBundleIdentifier = value
                model.updatePreferences(preferences)
            }
        )
    }
}

private struct IndexSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("索引") {
                LabeledContent("项目总数", value: "\(model.data.projects.count)")
                LabeledContent("顶层仓库", value: "\(model.data.projects.filter { !$0.isNested }.count)")
                LabeledContent("嵌套仓库", value: "\(model.data.projects.filter(\.isNested).count)")
                LabeledContent(
                    "失效路径",
                    value: "\(model.data.projects.filter { $0.availability != .available }.count)"
                )
            }

            Section("维护") {
                HStack {
                    Button("立即扫描") { model.startScan() }
                    Button("重建索引（保留说明）") { model.startScan() }
                    if model.isScanning {
                        Button("停止", role: .cancel) { model.cancelScan() }
                    }
                }
                HStack {
                    Button("导出数据…") { model.exportCustomData() }
                    Button("导入数据…") { model.importCustomData() }
                }
                Button("清除全部数据…", role: .destructive) { confirmClear = true }
                Text("重建索引会保留说明、标签和收藏；清除会删除扫描目录、索引、说明、标签、收藏和编辑器偏好。")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("关于") {
                LabeledContent("应用", value: "RepoGlance")
                LabeledContent("版本", value: versionDescription)
                Label(
                    "项目路径、README、说明和剪贴板历史只保存在本机。",
                    systemImage: "lock"
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("清除 RepoGlance 的全部本地数据？", isPresented: $confirmClear) {
            Button("清除全部数据", role: .destructive) { Task { await model.clearAllData() } }
            Button("取消", role: .cancel) {}
        }
    }

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version)（\(build)）"
    }
}
