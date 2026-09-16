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
        .alert("无法完成操作", isPresented: Binding(
            get: { model.presentedError != nil && ToolboxWindowCoordinator.shared.isKeyWindow },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("好", role: .cancel) { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
    }

    private var sidebar: some View {
        NativeSidebar {
            NativeSearchField(
                text: $toolbox.searchQuery,
                placeholder: "搜索工具…",
                focusOnAppear: false,
                usesSidebarAppearance: true,
                preferredHeight: 28,
                accessibilityIdentifier: "toolbox-search-field",
                usesResultNavigation: true,
                onMoveUp: { selectAdjacentTool(offset: -1) },
                onMoveDown: { selectAdjacentTool(offset: 1) },
                onSubmit: { ToolboxWindowCoordinator.shared.focusInput() },
                onEscape: { toolbox.searchQuery = "" }
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
                    SidebarSearchEmptyState { toolbox.searchQuery = "" }
                }
            }
            .accessibilityIdentifier("toolbox-sidebar")
        }
    }

    private var workbench: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(toolbox.selectedTool.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if toolbox.oversizedTools.contains(toolbox.selectedTool) {
                    Label("内容超过 1 MB，本次不会恢复", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .fixedSize(horizontal: false, vertical: true)

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

    private func selectAdjacentTool(offset: Int) {
        let tools = filteredTools
        guard !tools.isEmpty else { return }
        let index = tools.firstIndex(of: toolbox.selectedTool) ?? (offset > 0 ? -1 : tools.count)
        model.selectTool(tools[min(max(index + offset, 0), tools.count - 1)])
    }

    private var selectionBinding: Binding<DeveloperToolID?> {
        Binding(
            get: { toolbox.selectedTool },
            set: { tool in
                // AppKit's List can write selection while reconciling filtered rows.
                guard let tool else { return }
                DispatchQueue.main.async { model.selectTool(tool) }
            }
        )
    }

    private var favoriteTools: [DeveloperToolID] {
        DeveloperToolID.allCases.filter { model.data.toolboxPreferences.favoriteToolIDs.contains($0) }
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
                case "k":
                    ToolboxWindowCoordinator.shared.clearContent()
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
