import AppKit
import SwiftUI

struct SearchPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var onPreferredHeightChange: (CGFloat) -> Void = { _ in }
    @State private var projectSelectionIndex = 0
    @State private var clipboardSelectionIndex = 0
    @State private var removedClipboardItem: (item: ClipboardItem, index: Int)?
    @State private var confirmClearClipboardHistory = false

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()
            content
            if removedClipboardItem != nil {
                undoBar
                Divider()
            }
            statusBar
        }
        .frame(width: 620)
        .frame(minHeight: 300, maxHeight: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.42), lineWidth: 0.5)
        }
        .onChange(of: model.appliedProjectQuery) { _, _ in
            projectSelectionIndex = 0
            syncProjectSelection()
            updatePreferredHeight()
        }
        .onChange(of: model.clipboardQuery) { _, _ in
            clipboardSelectionIndex = 0
            syncClipboardSelection()
            updatePreferredHeight()
        }
        .onChange(of: model.quickPanelMode) { _, mode in
            PreviewPanelCoordinator.shared.hideImmediately()
            removedClipboardItem = nil
            if mode == .projects { syncProjectSelection() }
            else { syncClipboardSelection() }
            updatePreferredHeight()
        }
        .onChange(of: model.visibleProjects.count) { _, _ in
            updatePreferredHeight()
        }
        .onChange(of: model.visibleClipboardItems.count) { _, _ in
            updatePreferredHeight()
        }
        .onChange(of: model.data.scanRoots.count) { _, _ in
            updatePreferredHeight()
        }
        .onAppear {
            if model.quickPanelMode == .projects { syncProjectSelection() }
            else { syncClipboardSelection() }
            // NSHostingView finishes applying its initial fitting size after onAppear.
            // Resize on the next run-loop turn so the compact height wins on first show.
            DispatchQueue.main.async {
                updatePreferredHeight()
            }
#if DEBUG
            if
                ProcessInfo.processInfo.arguments.contains("--show-preview"),
                let project = selectableProjects.first
            {
                DispatchQueue.main.async {
                    model.selectedProjectID = project.id
                    PreviewPanelCoordinator.shared.enter(project: project, model: model)
                }
            } else if
                ProcessInfo.processInfo.arguments.contains("--show-project-editor"),
                let project = selectableProjects.first
            {
                DispatchQueue.main.async {
                    model.editingProjectID = project.id
                    SearchWindowCoordinator.shared.hide()
                    openWindow(id: "project-editor")
                }
            }
#endif
        }
        .alert("RepoGlance", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
        .confirmationDialog("清空剪贴板历史？", isPresented: $confirmClearClipboardHistory) {
            Button("清空历史", role: .destructive) {
                model.clearClipboardHistory()
                removedClipboardItem = nil
                clipboardSelectionIndex = 0
                syncClipboardSelection()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除本机保存的全部剪贴板文本，无法撤销。")
        }
    }

    private var commandBar: some View {
        HStack(spacing: 10) {
            Picker("快速面板模式", selection: $model.quickPanelMode) {
                Label("项目", systemImage: "folder")
                    .tag(QuickPanelMode.projects)
                Label("剪贴板", systemImage: "clipboard")
                    .tag(QuickPanelMode.clipboard)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 176)
            .accessibilityLabel("快速面板模式")
            .accessibilityIdentifier("quickPanelModePicker")
            .help("项目 ⌘1 · 剪贴板 ⌘2")

            NativeSearchField(
                text: activeQueryBinding,
                placeholder: model.quickPanelMode == .projects
                    ? "搜索项目、路径、说明或标签…"
                    : "搜索剪贴板文本…",
                isEnabled: model.quickPanelMode == .clipboard || !model.data.scanRoots.isEmpty,
                preferredHeight: 32,
                onMoveUp: { moveSelection(.up) },
                onMoveDown: { moveSelection(.down) },
                onSubmit: performPrimaryAction,
                onChooseOpeningMethod: chooseOpeningMethod,
                onRevealInFinder: revealSelection,
                onEditProject: editSelection,
                onRefresh: refreshProjects,
                onOpenSettings: {
                    SearchWindowCoordinator.shared.hide()
                    SettingsWindowCoordinator.shared.show(model: model)
                },
                onEnterPreview: enterPreview,
                onSelectProjects: { model.quickPanelMode = .projects },
                onSelectClipboard: { model.quickPanelMode = .clipboard },
                onCopySelection: copySelectionWithoutClosing,
                onDeleteSelection: deleteClipboardSelection,
                onClearClipboardHistory: requestClearClipboardHistory,
                onEscape: handleEscape
            )
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)

            if model.quickPanelMode == .clipboard {
                Image(
                    systemName: model.data.preferences.clipboardHistoryEnabled
                        ? "record.circle.fill"
                        : "pause.circle"
                )
                .foregroundStyle(.secondary)
                .help(model.data.preferences.clipboardHistoryEnabled ? "剪贴板记录中" : "剪贴板记录已暂停")
                .accessibilityLabel(model.data.preferences.clipboardHistoryEnabled ? "记录中" : "已暂停")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch model.quickPanelMode {
        case .projects:
            projectContent
        case .clipboard:
            clipboardContent
        }
    }

    @ViewBuilder
    private var projectContent: some View {
        if model.data.scanRoots.isEmpty {
            ContentUnavailableView {
                Label("开始使用 RepoGlance", systemImage: "folder.badge.plus")
            } description: {
                VStack(spacing: 6) {
                    Text("选择 dev 或 projects 文件夹，自动发现其中的 Git 仓库。")
                    Label("路径、README 摘要和说明仅保存在本机", systemImage: "lock")
                        .font(.caption)
                        .accessibilityIdentifier("local-privacy-note")
                }
            } actions: {
                Button("选择扫描文件夹…") { model.chooseAndAddScanRoot() }
            }
            .frame(maxHeight: .infinity)
            .padding()
        } else if
            !model.isProjectSearchPending,
            !model.appliedProjectQuery.isEmpty,
            model.visibleProjects.isEmpty,
            !model.isScanning
        {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("没有找到“\(model.appliedProjectQuery)”")
                    .font(.headline)
                Text("尝试项目名称、路径、说明或标签。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("清除搜索") { model.query = "" }
                    Button("重新扫描") { model.startScan() }
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                projectResultsSummary
                Divider()
                projectList
            }
        }
    }

    private var projectResultsSummary: some View {
        HStack(spacing: 7) {
            if model.isProjectSearchPending {
                ProgressView()
                    .controlSize(.mini)
                Text("正在筛选…")
                    .accessibilityIdentifier("project-search-pending")
            } else if model.appliedProjectQuery.isEmpty {
                Text("\(model.indexedProjects.count) 个项目")
            } else {
                Text("\(model.visibleProjects.count) 个结果")
                    .accessibilityIdentifier("project-result-count")
            }

            Spacer()

            if !model.appliedProjectQuery.isEmpty, !model.isProjectSearchPending {
                Text("匹配名称、路径、说明、标签与 README")
            } else {
                Text("悬停查看说明")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.quaternary.opacity(0.35))
    }

    private var projectList: some View {
        List(selection: $model.selectedProjectID) {
            if model.appliedProjectQuery.isEmpty {
                if !model.recentProjects.isEmpty {
                    projectSection(title: "最近使用", projects: Array(model.recentProjects.prefix(5)))
                }
                let recentIDs = Set(model.recentProjects.prefix(5).map(\.id))
                let favorites = model.favoriteProjects.filter { !recentIDs.contains($0.id) }
                if !favorites.isEmpty {
                    projectSection(title: "收藏", projects: Array(favorites.prefix(5)))
                }
                if model.recentProjects.isEmpty && favorites.isEmpty {
                    projectSection(title: "项目", projects: Array(model.indexedProjects.prefix(12)))
                }
            } else {
                let excerpts = Dictionary(
                    model.searchMatches.compactMap { match in
                        match.matchedExcerpt.map { (match.id, $0) }
                    },
                    uniquingKeysWith: { _, last in last }
                )
                ForEach(model.visibleProjects.prefix(200)) { project in
                    projectRow(project, excerpt: excerpts[project.id])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 8, for: .scrollContent)
        .contentMargins(.vertical, 4, for: .scrollContent)
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("projectResults")
    }

    private func projectSection(
        title: String,
        projects: [ProjectRecord],
        excerpts: [String: String] = [:]
    ) -> some View {
        Section {
            ForEach(projects) { project in
                projectRow(project, excerpt: excerpts[project.id])
            }
        } header: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
                .padding(.top, 4)
                .padding(.bottom, 2)
        }
    }

    private func projectRow(_ project: ProjectRecord, excerpt: String?) -> some View {
        ProjectRowView(
            project: project,
            depth: hierarchyDepth(for: project),
            isSelected: model.selectedProjectID == project.id,
            matchedExcerpt: excerpt
        )
        .tag(project.id)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.visible, edges: .bottom)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var clipboardContent: some View {
        if !model.data.preferences.clipboardHistoryEnabled && model.data.clipboardItems.isEmpty {
            ContentUnavailableView {
                Label("剪贴板记录未启用", systemImage: "clipboard")
            } description: {
                Text("启用后仅在本机保存新复制的纯文本，不会自动粘贴。")
            } actions: {
                Button("启用剪贴板记录") { model.setClipboardHistoryEnabled(true) }
            }
            .frame(maxHeight: .infinity)
            .padding()
        } else if model.visibleClipboardItems.isEmpty {
            ContentUnavailableView(
                model.clipboardQuery.isEmpty ? "还没有剪贴板记录" : "没有匹配内容",
                systemImage: "clipboard"
            )
            .frame(maxHeight: .infinity)
            .padding()
        } else {
            clipboardList
        }
    }

    private var clipboardList: some View {
        List(selection: $model.selectedClipboardItemID) {
            ForEach(Array(clipboardGroups.enumerated()), id: \.offset) { _, items in
                Section(dateSectionTitle(items[0].copiedAt)) {
                    ForEach(items) { item in
                        ClipboardQuickRow(
                            item: item,
                            isSelected: model.selectedClipboardItemID == item.id,
                            onCopy: { copyClipboardItem(item, close: true) },
                            onDelete: { deleteClipboardItem(item) }
                        )
                        .tag(item.id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 8, for: .scrollContent)
        .contentMargins(.vertical, 4, for: .scrollContent)
        .frame(maxHeight: .infinity)
        .accessibilityIdentifier("clipboardHistoryList")
    }

    private var undoBar: some View {
        HStack {
            Text("已删除剪贴板记录")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("撤销") {
                guard let removedClipboardItem else { return }
                model.restoreClipboardItem(removedClipboardItem.item, at: removedClipboardItem.index)
                self.removedClipboardItem = nil
                syncClipboardSelection()
            }
            .buttonStyle(.link)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if model.quickPanelMode == .projects {
                projectStatus
            } else {
                clipboardStatus
            }
            Spacer()
            contextualShortcutHints
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    @ViewBuilder
    private var projectStatus: some View {
        if model.isScanning {
            ProgressView().controlSize(.small)
            Text("扫描中 · \(model.discoveredCount) 个")
                .foregroundStyle(.secondary)
        } else if !model.scanIssues.isEmpty {
            Label("\(model.scanIssues.count) 个目录问题", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else {
            Text("\(model.indexedProjects.count) 个项目 · 已更新")
                .foregroundStyle(.secondary)
        }
    }

    private var clipboardStatus: some View {
        HStack(spacing: 6) {
            Text("\(model.data.clipboardItems.count) 条 · 仅保存在本机")
                .foregroundStyle(.secondary)
            Button(model.data.preferences.clipboardHistoryEnabled ? "暂停" : "恢复") {
                model.setClipboardHistoryEnabled(!model.data.preferences.clipboardHistoryEnabled)
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private var contextualShortcutHints: some View {
        if model.quickPanelMode == .projects {
            Text("↑↓ 选择").foregroundStyle(.secondary)
            Text("↵ 打开").foregroundStyle(.secondary)
            Text("⌘→ 预览").foregroundStyle(.secondary)
        } else {
            Text("↑↓ 选择").foregroundStyle(.secondary)
            Text("↵ 复制并关闭").foregroundStyle(.secondary)
            Text("⌘C 连续复制").foregroundStyle(.secondary)
        }
    }

    private var activeQueryBinding: Binding<String> {
        Binding(
            get: {
                model.quickPanelMode == .projects ? model.query : model.clipboardQuery
            },
            set: { value in
                if model.quickPanelMode == .projects { model.query = value }
                else { model.clipboardQuery = value }
            }
        )
    }

    private var selectableProjects: [ProjectRecord] {
        if !model.appliedProjectQuery.isEmpty { return model.visibleProjects }
        let recent = Array(model.recentProjects.prefix(5))
        let recentIDs = Set(recent.map(\.id))
        let favorites = model.favoriteProjects.filter { !recentIDs.contains($0.id) }
        let combined = recent + favorites
        return combined.isEmpty ? Array(model.indexedProjects.prefix(12)) : combined
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        if model.quickPanelMode == .projects {
            if model.isProjectSearchPending {
                model.flushProjectSearch()
                projectSelectionIndex = 0
            }
            guard !selectableProjects.isEmpty else { return }
            switch direction {
            case .down: projectSelectionIndex = min(projectSelectionIndex + 1, selectableProjects.count - 1)
            case .up: projectSelectionIndex = max(projectSelectionIndex - 1, 0)
            default: break
            }
            syncProjectSelection(showPreviewImmediately: true)
        } else {
            guard !model.visibleClipboardItems.isEmpty else { return }
            switch direction {
            case .down:
                clipboardSelectionIndex = min(clipboardSelectionIndex + 1, model.visibleClipboardItems.count - 1)
            case .up:
                clipboardSelectionIndex = max(clipboardSelectionIndex - 1, 0)
            default: break
            }
            syncClipboardSelection()
        }
    }

    private func syncProjectSelection(showPreviewImmediately: Bool = false) {
        guard selectableProjects.indices.contains(projectSelectionIndex) else {
            model.selectedProjectID = nil
            return
        }
        let project = selectableProjects[projectSelectionIndex]
        model.selectedProjectID = project.id
        if showPreviewImmediately {
            PreviewPanelCoordinator.shared.showImmediately(project: project, model: model)
        } else {
            PreviewPanelCoordinator.shared.scheduleShow(project: project, model: model)
        }
    }

    private func syncClipboardSelection() {
        guard model.visibleClipboardItems.indices.contains(clipboardSelectionIndex) else {
            model.selectedClipboardItemID = nil
            return
        }
        model.selectedClipboardItemID = model.visibleClipboardItems[clipboardSelectionIndex].id
    }

    private func performPrimaryAction() {
        if model.quickPanelMode == .projects {
            if model.isProjectSearchPending {
                model.flushProjectSearch()
                projectSelectionIndex = 0
                syncProjectSelection()
            }
            guard selectableProjects.indices.contains(projectSelectionIndex) else { return }
            Task { await model.open(selectableProjects[projectSelectionIndex]) }
        } else if model.visibleClipboardItems.indices.contains(clipboardSelectionIndex) {
            copyClipboardItem(model.visibleClipboardItems[clipboardSelectionIndex], close: true)
        }
    }

    private func chooseOpeningMethod() {
        commitPendingProjectSearch()
        guard model.quickPanelMode == .projects,
              selectableProjects.indices.contains(projectSelectionIndex)
        else { return }
        Task { await model.chooseAndOpen(selectableProjects[projectSelectionIndex]) }
    }

    private func revealSelection() {
        commitPendingProjectSearch()
        guard model.quickPanelMode == .projects,
              selectableProjects.indices.contains(projectSelectionIndex)
        else { return }
        model.revealInFinder(selectableProjects[projectSelectionIndex])
    }

    private func editSelection() {
        commitPendingProjectSearch()
        guard model.quickPanelMode == .projects,
              selectableProjects.indices.contains(projectSelectionIndex)
        else { return }
        model.editingProjectID = selectableProjects[projectSelectionIndex].id
        SearchWindowCoordinator.shared.hide()
        openWindow(id: "project-editor")
    }

    private func refreshProjects() {
        guard model.quickPanelMode == .projects else { return }
        model.startScan()
    }

    private func enterPreview() {
        commitPendingProjectSearch()
        guard model.quickPanelMode == .projects,
              selectableProjects.indices.contains(projectSelectionIndex)
        else { return }
        let project = selectableProjects[projectSelectionIndex]
        model.selectedProjectID = project.id
        PreviewPanelCoordinator.shared.enter(project: project, model: model)
    }

    private func copySelectionWithoutClosing() {
        if model.quickPanelMode == .projects {
            commitPendingProjectSearch()
            guard selectableProjects.indices.contains(projectSelectionIndex) else { return }
            model.copyPath(selectableProjects[projectSelectionIndex])
        } else if model.visibleClipboardItems.indices.contains(clipboardSelectionIndex) {
            copyClipboardItem(model.visibleClipboardItems[clipboardSelectionIndex], close: false)
        }
    }

    private func copyClipboardItem(_ item: ClipboardItem, close: Bool) {
        model.copyClipboardItem(item)
        if close { SearchWindowCoordinator.shared.hide() }
    }

    private func deleteClipboardSelection() {
        guard model.quickPanelMode == .clipboard,
              model.visibleClipboardItems.indices.contains(clipboardSelectionIndex)
        else { return }
        deleteClipboardItem(model.visibleClipboardItems[clipboardSelectionIndex])
    }

    private func requestClearClipboardHistory() {
        guard model.quickPanelMode == .clipboard,
              model.clipboardQuery.isEmpty,
              !model.data.clipboardItems.isEmpty
        else { return }
        confirmClearClipboardHistory = true
    }

    private func deleteClipboardItem(_ item: ClipboardItem) {
        guard let index = model.data.clipboardItems.firstIndex(where: { $0.id == item.id }) else { return }
        removedClipboardItem = (item, index)
        model.removeClipboardItem(item)
        clipboardSelectionIndex = min(clipboardSelectionIndex, max(0, model.visibleClipboardItems.count - 1))
        syncClipboardSelection()
    }

    private func handleEscape() {
        if model.quickPanelMode == .projects {
            if PreviewPanelCoordinator.shared.isInteractive {
                PreviewPanelCoordinator.shared.returnToSearch()
            } else if !model.query.isEmpty {
                model.query = ""
            } else {
                SearchWindowCoordinator.shared.hide()
            }
        } else if !model.clipboardQuery.isEmpty {
            model.clipboardQuery = ""
        } else {
            SearchWindowCoordinator.shared.hide()
        }
    }

    private func commitPendingProjectSearch() {
        guard model.quickPanelMode == .projects, model.isProjectSearchPending else { return }
        model.flushProjectSearch()
        projectSelectionIndex = 0
        syncProjectSelection()
    }

    private func updatePreferredHeight() {
        onPreferredHeightChange(preferredPanelHeight)
    }

    private var preferredPanelHeight: CGFloat {
        switch model.quickPanelMode {
        case .projects:
            guard !model.data.scanRoots.isEmpty else { return 400 }
            if
                !model.isProjectSearchPending,
                !model.appliedProjectQuery.isEmpty,
                model.visibleProjects.isEmpty
            {
                return 360
            }

            let projectCount = min(selectableProjects.count, 10)
            let sectionCount: Int
            if model.appliedProjectQuery.isEmpty {
                let recentCount = model.recentProjects.isEmpty ? 0 : 1
                let recentIDs = Set(model.recentProjects.prefix(5).map(\.id))
                let hasFavorites = model.favoriteProjects.contains { !recentIDs.contains($0.id) }
                sectionCount = max(1, recentCount + (hasFavorites ? 1 : 0))
            } else {
                sectionCount = 0
            }
            let estimatedRows = CGFloat(projectCount) * (model.appliedProjectQuery.isEmpty ? 46 : 52)
            let estimatedSections = CGFloat(sectionCount) * 25
            return min(640, max(300, 118 + estimatedRows + estimatedSections))

        case .clipboard:
            guard !model.visibleClipboardItems.isEmpty else { return 360 }
            let rowCount = min(model.visibleClipboardItems.count, 8)
            return min(640, max(340, 94 + CGFloat(rowCount) * 62))
        }
    }

    private func shouldShowDateHeader(at index: Int) -> Bool {
        let items = model.visibleClipboardItems
        guard items.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return !Calendar.current.isDate(items[index].copiedAt, inSameDayAs: items[index - 1].copiedAt)
    }

    private var clipboardGroups: [[ClipboardItem]] {
        model.visibleClipboardItems.reduce(into: [[ClipboardItem]]()) { groups, item in
            if let last = groups.last?.last,
               Calendar.current.isDate(last.copiedAt, inSameDayAs: item.copiedAt) {
                groups[groups.count - 1].append(item)
            } else {
                groups.append([item])
            }
        }
    }

    private func dateSectionTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func hierarchyDepth(for project: ProjectRecord) -> Int {
        var depth = 0
        var current = project.parentProjectID
        let byID = Dictionary(
            model.data.projects.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
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
}

private struct ClipboardQuickRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onCopy) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovering || isSelected {
                Button("复制", action: onCopy)
                    .buttonStyle(.borderless)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("删除此剪贴板记录")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 68)
        .foregroundStyle(.primary)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("复制并关闭", action: onCopy)
            Button("删除", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.text), \(metadata)")
        .accessibilityValue(isSelected ? "已选择，按 Enter 复制并关闭" : "")
    }

    private var metadata: String {
        let lineCount = max(1, item.text.split(separator: "\n", omittingEmptySubsequences: false).count)
        let countDescription = lineCount > 1 ? "\(lineCount) 行" : "\(item.text.count) 个字符"
        return "\(item.copiedAt.formatted(.relative(presentation: .named))) · \(countDescription)"
    }
}

struct WindowMaterialBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = WindowMaterialEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
    }
}

private final class WindowMaterialEffectView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
    }
}
