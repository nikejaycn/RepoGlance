import SwiftUI

struct ProjectPreviewView: View {
    enum ContentTab: String, CaseIterable, Identifiable {
        case description = "自定义说明"
        case readme = "README"
        var id: String { rawValue }
    }

    private enum FocusTarget: Hashable {
        case contentPicker
        case openButton
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    let projectID: String
    let focusContentOnAppear: Bool
    @State private var selectedTab: ContentTab
    @FocusState private var focusedControl: FocusTarget?

    init(projectID: String, initialTab: ContentTab, focusContentOnAppear: Bool = false) {
        self.projectID = projectID
        self.focusContentOnAppear = focusContentOnAppear
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            if let project {
                VStack(spacing: 0) {
                    header(project)
                    Divider()
                    if hasBothSources(project) {
                        Picker("内容", selection: $selectedTab) {
                            ForEach(ContentTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(12)
                        .focused($focusedControl, equals: .contentPicker)
                    }
                    content(project)
                    Divider()
                    actions(project)
                }
            } else {
                ContentUnavailableView("项目已不在索引中", systemImage: "folder.badge.questionmark")
            }
        }
        .frame(width: 420)
        .frame(minHeight: 420)
        .background(.regularMaterial)
        .accessibilityIdentifier("project-preview")
        .accessibilityValue(focusContentOnAppear ? "交互预览" : "自动预览")
        .onAppear {
            guard focusContentOnAppear else { return }
            DispatchQueue.main.async {
                focusedControl = project.map(hasBothSources) == true ? .contentPicker : .openButton
            }
        }
        .onExitCommand { PreviewPanelCoordinator.shared.returnToSearch() }
    }

    private func header(_ project: ProjectRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: project.availability == .available ? "folder" : "exclamationmark.triangle")
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .accessibilityIdentifier("preview-project-name")
                Text((project.canonicalPath as NSString).abbreviatingWithTildeInPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(parentDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                previewTags(project.tags)
            }
            Spacer()
            Button { model.toggleFavorite(project) } label: {
                Image(systemName: project.isFavorite ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            .help(project.isFavorite ? "取消收藏" : "收藏")
            .accessibilityLabel(project.isFavorite ? "取消收藏 \(project.name)" : "收藏 \(project.name)")
        }
        .padding(12)
    }

    @ViewBuilder
    private func previewTags(_ tags: [String]) -> some View {
        if !tags.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    if tags.count > 2 { tagCount(tags.count - 2, prefix: "另外") }
                }
                tagCount(tags.count, prefix: "共")
            }
        }
    }

    private func tagCount(_ count: Int, prefix: String) -> some View {
        Text("\(count) 个标签")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(prefix) \(count) 个标签")
    }

    @ViewBuilder
    private func content(_ project: ProjectRecord) -> some View {
        let markdown = selectedMarkdown(project)
        if markdown.isEmpty {
            ContentUnavailableView {
                Label("没有项目说明", systemImage: "doc.text")
            } description: {
                Text("可以添加自定义说明，或在项目中创建 README。")
            } actions: {
                Button("添加说明…") { editProject() }
            }
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LimitedMarkdownText(markdown: markdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                if selectedTab == .readme, project.readmeWasTruncated {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("仅显示 README 开头 20 KB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("查看完整 README") { model.openFullReadme(project) }
                            .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .accessibilityLabel(selectedTab == .description ? "自定义说明内容" : "README 内容")
            .accessibilityValue(accessibleText(markdown))
            .accessibilityIdentifier("preview-content")
        }
    }

    private func actions(_ project: ProjectRecord) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                openButton(project)
                openingMenu(project)
                Spacer()
                editButton
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    openButton(project)
                    openingMenu(project)
                }
                editButton
            }
        }
        .padding(12)
    }

    private func openButton(_ project: ProjectRecord) -> some View {
        Button("打开") { Task { await model.open(project) } }
            .keyboardShortcut(.defaultAction)
            .focused($focusedControl, equals: .openButton)
    }

    private func openingMenu(_ project: ProjectRecord) -> some View {
        Menu("其他方式") {
            ForEach(model.data.editors) { editor in
                Button(editor.name) { Task { await model.open(project, editorBundleIdentifier: editor.bundleIdentifier) } }
            }
            Divider()
            Button("在 Finder 中显示") { model.revealInFinder(project) }
            Button("在终端中打开") { Task { await model.openInTerminal(project) } }
        }
    }

    private var editButton: some View {
        Button("编辑项目信息…") { editProject() }
            .buttonStyle(.link)
    }

    private func hasBothSources(_ project: ProjectRecord) -> Bool {
        !project.customDescription.isEmpty && !(project.readmeExcerpt ?? "").isEmpty
    }

    private func selectedMarkdown(_ project: ProjectRecord) -> String {
        if selectedTab == .description, !project.customDescription.isEmpty { return project.customDescription }
        return project.readmeExcerpt ?? ""
    }

    private func accessibleText(_ markdown: String) -> String {
        let excerpt = String(markdown.prefix(1_000))
        if let attributed = try? AttributedString(
            markdown: excerpt,
            options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        ) {
            return String(attributed.characters)
        }
        return excerpt
    }

    private var parentDescription: String {
        guard let project else { return "" }
        guard let parentID = project.parentProjectID else { return "顶层项目" }
        let parentName = model.data.projects.first { $0.id == parentID }?.name
            ?? URL(fileURLWithPath: parentID).lastPathComponent
        return "位于 \(parentName)"
    }

    private func editProject() {
        model.editingProjectID = projectID
        SearchWindowCoordinator.shared.hide()
        openWindow(id: "project-editor")
    }

    private var project: ProjectRecord? {
        model.data.projects.first { $0.id == projectID }
    }
}

struct LimitedMarkdownText: View {
    let markdown: String

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
            .accessibilityIdentifier("limited-markdown-text")
    }

    private var attributed: AttributedString {
        (try? AttributedString(
            markdown: sanitizedMarkdown,
            options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
        )) ?? AttributedString(sanitizedMarkdown)
    }

    private var sanitizedMarkdown: String {
        LimitedMarkdown.sanitize(markdown)
    }
}
