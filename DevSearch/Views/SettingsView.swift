import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
            ScanRootsSettingsView()
                .tabItem { Label("扫描目录", systemImage: "folder") }
            EditorSettingsView()
                .tabItem { Label("编辑器", systemImage: "hammer") }
            IndexSettingsView()
                .tabItem { Label("索引与数据", systemImage: "externaldrive") }
            AboutSettingsView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .padding(16)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Toggle("登录时启动", isOn: launchAtLoginBinding)
            Toggle("启用全局快捷键", isOn: preferenceBinding(\.globalShortcutEnabled))
            Picker("快捷键", selection: preferenceBinding(\.globalShortcut)) {
                ForEach(GlobalShortcut.allCases) { shortcut in
                    Text(shortcut.displayName).tag(shortcut)
                }
            }
            .disabled(!model.data.preferences.globalShortcutEnabled)
            Toggle("打开项目后关闭搜索面板", isOn: preferenceBinding(\.closeAfterOpening))
            Picker("预览等待时间", selection: previewDelayBinding) {
                Text("快速（250 ms）").tag(250)
                Text("标准（400 ms）").tag(400)
                Text("较慢（600 ms）").tag(600)
            }
            Picker("定时兜底扫描", selection: preferenceBinding(\.automaticScanIntervalMinutes)) {
                Text("关闭（仍监听文件变化）").tag(0)
                Text("每 5 分钟").tag(5)
                Text("每 15 分钟").tag(15)
                Text("每 30 分钟").tag(30)
                Text("每 60 分钟").tag(60)
            }
            Picker("终端应用", selection: preferenceBinding(\.terminalBundleIdentifier)) {
                Text("终端").tag("com.apple.Terminal")
                Text("iTerm").tag("com.googlecode.iterm2")
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

private struct ScanRootsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var rootPendingRemoval: ScanRoot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("扫描目录").font(.title2.weight(.semibold))
                Spacer()
                Button("添加目录…") { model.chooseAndAddScanRoot() }
            }

            if model.data.scanRoots.isEmpty {
                ContentUnavailableView("没有扫描目录", systemImage: "folder.badge.plus")
            } else {
                List {
                    ForEach(model.data.scanRoots) { root in
                        DisclosureGroup {
                            Form {
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
                            }
                            .formStyle(.grouped)
                            .padding(.top, 4)
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
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除扫描目录 \(root.displayPath)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !model.scanIssues.isEmpty {
                GroupBox("扫描问题") {
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding(8)
                }
            }

            Divider()
            HStack {
                Text("已排除项目").font(.headline)
                Spacer()
            }
            if model.data.exclusionRules.isEmpty {
                Text("没有排除规则").foregroundStyle(.secondary)
            } else {
                List(model.data.exclusionRules) { rule in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(URL(fileURLWithPath: rule.canonicalPath).lastPathComponent)
                            Text(rule.canonicalPath).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rule.includesDescendants ? "包含子项目" : "仅当前项目")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("恢复") { model.restoreExclusion(rule) }
                    }
                }
            }
        }
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
            Picker("全局默认编辑器", selection: defaultEditorBinding) {
                Text("未选择").tag(String?.none)
                ForEach(model.data.editors) { editor in
                    Text(editor.name).tag(Optional(editor.bundleIdentifier))
                }
            }

            Section("已发现的编辑器") {
                if model.data.editors.isEmpty {
                    Text("没有发现支持的编辑器").foregroundStyle(.secondary)
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
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除编辑器 \(editor.name)")
                            }
                        }
                    }
                }
            }
            Button("添加其他应用…") { model.chooseAndAddEditor() }
        }
        .formStyle(.grouped)
    }

    private var defaultEditorBinding: Binding<String?> {
        Binding(
            get: { model.data.preferences.defaultEditorBundleIdentifier },
            set: { model.setDefaultEditor($0) }
        )
    }
}

private struct IndexSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmClear = false

    var body: some View {
        Form {
            LabeledContent("项目总数", value: "\(model.data.projects.count)")
            LabeledContent("顶层仓库", value: "\(model.data.projects.filter { !$0.isNested }.count)")
            LabeledContent("嵌套仓库", value: "\(model.data.projects.filter(\.isNested).count)")
            LabeledContent("失效路径", value: "\(model.data.projects.filter { $0.availability != .available }.count)")
            HStack {
                Button("立即扫描") { model.startScan() }
                Button("重建索引（保留说明）") { model.startScan() }
                if model.isScanning { Button("停止") { model.cancelScan() } }
            }
            HStack {
                Button("导出数据…") { model.exportCustomData() }
                Button("导入数据…") { model.importCustomData() }
            }
            Section {
                Button("清除全部数据…", role: .destructive) { confirmClear = true }
            } footer: {
                Text("重建索引会保留说明、标签和收藏；清除会删除扫描目录、索引、说明、标签、收藏和编辑器偏好。")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("清除 Dev Search 的全部本地数据？", isPresented: $confirmClear) {
            Button("清除全部数据", role: .destructive) { Task { await model.clearAllData() } }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
            Text("Dev Search").font(.title2.weight(.semibold))
            Text(versionDescription)
                .foregroundStyle(.secondary)
            Text("项目路径、README 和自定义说明只保存在本机。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "版本 \(version)（\(build)）"
    }
}
