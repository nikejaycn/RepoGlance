import SwiftUI

struct SearchPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var selectionIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            content
            Divider()
            statusBar
        }
        .frame(width: 420)
        .frame(minHeight: 184, maxHeight: 620)
        .onChange(of: model.query) { _, _ in selectionIndex = 0; syncSelection() }
        .onChange(of: selectionIndex) { _, _ in syncSelection() }
        .alert("Dev Search", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
    }

    private var searchHeader: some View {
        NativeSearchField(
            text: $model.query,
            placeholder: "搜索项目、路径、说明或标签…",
            onMoveUp: { moveSelection(.up) },
            onMoveDown: { moveSelection(.down) },
            onSubmit: openSelection,
            onChooseOpeningMethod: chooseOpeningMethod,
            onRevealInFinder: revealSelection,
            onEditProject: editSelection,
            onRefresh: { model.startScan() },
            onOpenSettings: { openSettings() },
            onEnterPreview: enterPreview,
            onEscape: handleEscape
        )
        .frame(height: 36)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.data.scanRoots.isEmpty {
            ContentUnavailableView {
                Label("开始使用 Dev Search", systemImage: "folder.badge.plus")
            } description: {
                VStack(spacing: 6) {
                    Text("选择你的 dev 或 projects 文件夹，自动发现其中的 Git 仓库与嵌套仓库。")
                    Label("路径、README 摘要和说明仅保存在本机", systemImage: "lock")
                        .font(.caption)
                        .accessibilityIdentifier("local-privacy-note")
                }
            } actions: {
                VStack(spacing: 10) {
                    if model.data.editors.isEmpty {
                        Text("未发现支持的编辑器，可稍后在设置中添加。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("默认编辑器", selection: onboardingEditorBinding) {
                            Text("以后再说").tag(String?.none)
                            ForEach(model.data.editors) { editor in
                                Text(editor.name).tag(Optional(editor.bundleIdentifier))
                            }
                        }
                        .frame(width: 280)
                    }
                    Button("选择扫描文件夹…") { model.chooseAndAddScanRoot() }
                }
            }
            .frame(maxHeight: .infinity)
        } else if !model.query.isEmpty && model.visibleProjects.isEmpty && !model.isScanning {
            ContentUnavailableView.search(text: model.query)
                .frame(maxHeight: .infinity)
        } else {
            projectList
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if model.query.isEmpty {
                    if !model.favoriteProjects.isEmpty {
                        projectSection(title: "收藏", projects: model.favoriteProjects)
                    }
                    if !model.recentProjects.isEmpty {
                        projectSection(title: "最近使用", projects: model.recentProjects)
                    }
                    if model.favoriteProjects.isEmpty && model.recentProjects.isEmpty {
                        projectSection(title: "项目", projects: Array(model.indexedProjects.prefix(20)))
                    }
                } else {
                    projectSection(
                        title: "结果 \(model.visibleProjects.count)",
                        projects: Array(model.visibleProjects.prefix(200)),
                        excerpts: Dictionary(uniqueKeysWithValues: model.searchMatches.compactMap { match in
                            match.matchedExcerpt.map { (match.id, $0) }
                        })
                    )
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func projectSection(
        title: String,
        projects: [ProjectRecord],
        excerpts: [String: String] = [:]
    ) -> some View {
        Section {
            ForEach(projects) { project in
                ProjectRowView(
                    project: project,
                    depth: hierarchyDepth(for: project),
                    isSelected: model.selectedProjectID == project.id,
                    matchedExcerpt: excerpts[project.id]
                )
                Divider().padding(.leading, 36)
            }
        } header: {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(.bar)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if model.isScanning {
                ProgressView().controlSize(.small)
                Text("正在扫描… 已发现 \(model.discoveredCount) 个")
                    .foregroundStyle(.secondary)
                Button("停止") { model.cancelScan() }
                    .buttonStyle(.link)
            } else if !model.scanIssues.isEmpty {
                Label("\(model.scanIssues.count) 个目录问题", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(model.indexedProjects.count) 个项目 · 已更新")
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Button { model.startScan() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
                .help("重新扫描")
                .accessibilityLabel("重新扫描项目")
                .disabled(model.isScanning)
            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .help("设置")
                .accessibilityLabel("打开设置")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        .padding(.vertical, 2)
    }

    private var selectableProjects: [ProjectRecord] {
        if !model.query.isEmpty { return model.visibleProjects }
        let combined = model.favoriteProjects + model.recentProjects
        return combined.isEmpty ? Array(model.indexedProjects.prefix(20)) : combined
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !selectableProjects.isEmpty else { return }
        switch direction {
        case .down: selectionIndex = min(selectionIndex + 1, selectableProjects.count - 1)
        case .up: selectionIndex = max(selectionIndex - 1, 0)
        default: break
        }
        // Keyboard navigation should reveal immediately. In a one-result list
        // the index remains zero, so an onChange handler alone cannot do this.
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        let project = selectableProjects[selectionIndex]
        model.selectedProjectID = project.id
        PreviewPanelCoordinator.shared.showImmediately(project: project, model: model)
    }

    private func syncSelection() {
        guard selectableProjects.indices.contains(selectionIndex) else {
            model.selectedProjectID = nil
            return
        }
        let project = selectableProjects[selectionIndex]
        model.selectedProjectID = project.id
        PreviewPanelCoordinator.shared.scheduleShow(project: project, model: model)
    }

    private func openSelection() {
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        Task { await model.open(selectableProjects[selectionIndex]) }
    }

    private func chooseOpeningMethod() {
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        Task { await model.chooseAndOpen(selectableProjects[selectionIndex]) }
    }

    private func revealSelection() {
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        model.revealInFinder(selectableProjects[selectionIndex])
    }

    private func editSelection() {
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        model.editingProjectID = selectableProjects[selectionIndex].id
        SearchWindowCoordinator.shared.hide()
        openWindow(id: "project-editor")
    }

    private func enterPreview() {
        guard selectableProjects.indices.contains(selectionIndex) else { return }
        let project = selectableProjects[selectionIndex]
        model.selectedProjectID = project.id
        PreviewPanelCoordinator.shared.enter(project: project, model: model)
    }

    private func handleEscape() {
        if PreviewPanelCoordinator.shared.isInteractive {
            PreviewPanelCoordinator.shared.returnToSearch()
            return
        }
        if !model.query.isEmpty {
            model.query = ""
        } else {
            PreviewPanelCoordinator.shared.hideImmediately()
            NSApp.keyWindow?.orderOut(nil)
        }
    }

    private func hierarchyDepth(for project: ProjectRecord) -> Int {
        var depth = 0
        var current = project.parentProjectID
        let byID = Dictionary(uniqueKeysWithValues: model.data.projects.map { ($0.id, $0) })
        var visited = Set<String>()
        while let parentID = current, !visited.contains(parentID), let parent = byID[parentID] {
            visited.insert(parentID)
            depth += 1
            current = parent.parentProjectID
        }
        return min(depth, 2)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )
    }

    private var onboardingEditorBinding: Binding<String?> {
        Binding(
            get: { model.data.preferences.defaultEditorBundleIdentifier },
            set: { model.setDefaultEditor($0) }
        )
    }
}
