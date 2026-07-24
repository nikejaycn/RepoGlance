import SwiftUI

struct ProjectRowView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    let project: ProjectRecord
    let depth: Int
    let isSelected: Bool
    var matchedExcerpt: String? = nil
    @State private var screenFrame: NSRect?
    @State private var pendingExclusionIncludesDescendants: Bool?
    @State private var isHovering = false

    var body: some View {
        Button {
            Task { await model.open(project) }
        } label: {
            HStack(spacing: 8) {
                if depth > 0 {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }

                Image(systemName: projectIcon)
                    .frame(width: 18)
                    .foregroundStyle(project.availability == .available ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(project.name)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                            .help(project.name)
                        if let availabilityLabel {
                            Label(availabilityLabel, systemImage: projectIcon)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if project.isNested {
                        Text(nestedRelationship)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(abbreviatedPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let matchedExcerpt, !matchedExcerpt.isEmpty {
                        Text(matchedExcerpt.replacingOccurrences(of: "\n", with: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
                if project.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("已收藏")
                }
                if isHovering || isSelected {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minHeight: matchedExcerpt == nil ? 64 : 78)
            .contentShape(Rectangle())
            .background(ScreenFrameReader { screenFrame = $0 })
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(min(depth, 2)) * 14)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                model.selectedProjectID = project.id
                PreviewPanelCoordinator.shared.scheduleShow(project: project, model: model, anchorRect: screenFrame)
            } else {
                PreviewPanelCoordinator.shared.scheduleHide()
            }
        }
        .contextMenu {
            if project.availability == .available {
                Button("打开") { Task { await model.open(project) } }
                Menu("打开方式") {
                    ForEach(model.data.editors) { editor in
                        Button(editor.name) { Task { await model.open(project, editorBundleIdentifier: editor.bundleIdentifier) } }
                    }
                }
                Button("在 Finder 中显示") { model.revealInFinder(project) }
                Button("在终端中打开") { Task { await model.openInTerminal(project) } }
            } else if project.availability == .missing {
                Button("重新定位项目…") { model.chooseAndRelocate(project) }
                Button("删除失效记录", role: .destructive) { model.deleteProjectRecord(project) }
            } else {
                Text("磁盘未连接")
            }
            Divider()
            Button("复制路径") { model.copyPath(project) }
            Divider()
            Button(project.isFavorite ? "取消收藏" : "添加到收藏") { model.toggleFavorite(project) }
            Button("编辑项目信息…") {
                model.editingProjectID = project.id
                SearchWindowCoordinator.shared.hide()
                openWindow(id: "project-editor")
            }
            Divider()
            Button("排除此项目", role: .destructive) { pendingExclusionIncludesDescendants = false }
            if hasChildren {
                Button("排除此项目及子项目", role: .destructive) { pendingExclusionIncludesDescendants = true }
            }
        }
        .confirmationDialog("从索引中排除项目？", isPresented: exclusionDialogBinding) {
            Button(exclusionButtonTitle, role: .destructive) {
                guard let includesDescendants = pendingExclusionIncludesDescendants else { return }
                model.exclude(project, includingDescendants: includesDescendants)
                pendingExclusionIncludesDescendants = nil
            }
            Button("取消", role: .cancel) { pendingExclusionIncludesDescendants = nil }
        } message: {
            Text(exclusionMessage)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAction(named: "查看项目预览") {
            model.selectedProjectID = project.id
            PreviewPanelCoordinator.shared.enter(project: project, model: model)
        }
    }

    private var abbreviatedPath: String {
        (project.canonicalPath as NSString).abbreviatingWithTildeInPath
    }

    private var projectIcon: String {
        switch project.availability {
        case .available: "folder"
        case .missing: "exclamationmark.triangle"
        case .volumeOffline: "externaldrive.badge.xmark"
        }
    }

    private var availabilityLabel: String? {
        switch project.availability {
        case .available: nil
        case .missing: "路径失效"
        case .volumeOffline: "磁盘未连接"
        }
    }

    private var nestedRelationship: String {
        guard let parentID = project.parentProjectID else { return "子仓库" }
        let parentName = model.data.projects.first { $0.id == parentID }?.name
            ?? URL(fileURLWithPath: parentID).lastPathComponent
        return "子仓库 · 位于 \(parentName)"
    }

    private var hasChildren: Bool {
        model.data.projects.contains { $0.parentProjectID == project.id }
    }

    private var accessibilityDescription: String {
        var parts = [project.name]
        if project.isNested {
            let parentName = project.parentProjectID.flatMap { parentID in
                model.data.projects.first { $0.id == parentID }?.name
            }
            parts.append(parentName.map { "子仓库，父项目 \($0)" } ?? "子仓库")
        }
        parts.append(abbreviatedPath)
        if !project.tags.isEmpty { parts.append("标签 \(project.tags.joined(separator: "，"))") }
        if let availabilityLabel { parts.append(availabilityLabel) }
        return parts.joined(separator: "，")
    }

    private var exclusionDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingExclusionIncludesDescendants != nil },
            set: { if !$0 { pendingExclusionIncludesDescendants = nil } }
        )
    }

    private var exclusionButtonTitle: String {
        pendingExclusionIncludesDescendants == true ? "排除此项目及子项目" : "排除此项目"
    }

    private var exclusionMessage: String {
        if pendingExclusionIncludesDescendants == true {
            return "该项目和其下所有嵌套仓库将不再被索引。可随时在设置中恢复。"
        }
        return "只排除该项目，嵌套仓库仍会保留。可随时在设置中恢复。"
    }
}
