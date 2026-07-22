import AppKit
import SwiftUI

struct ProjectEditorHostView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if
            let id = model.editingProjectID,
            let project = model.data.projects.first(where: { $0.id == id })
        {
            ProjectEditorView(project: project)
                .id(project.id)
        } else {
            Color.clear
                .frame(width: 1, height: 1)
                .task { dismiss() }
        }
    }
}

struct ProjectEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let project: ProjectRecord

    @State private var displayName: String
    @State private var description: String
    @State private var tagText: String
    @State private var editorBundleIdentifier: String?
    @State private var showingDiscardConfirmation = false
    @State private var allowWindowClose = false

    init(project: ProjectRecord) {
        self.project = project
        _displayName = State(initialValue: project.displayName ?? "")
        _description = State(initialValue: project.customDescription)
        _tagText = State(initialValue: project.tags.joined(separator: ", "))
        _editorBundleIdentifier = State(initialValue: project.defaultEditorBundleIdentifier)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                fieldLabel("项目路径")
                                HStack {
                                    Text((project.canonicalPath as NSString).abbreviatingWithTildeInPath)
                                        .font(.body.monospaced())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                    Spacer()
                                    Button { model.copyPath(project) } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .help("复制路径")
                                    .accessibilityLabel("复制项目路径")
                                    Button { model.revealInFinder(project) } label: {
                                        Image(systemName: "folder")
                                    }
                                    .help("在 Finder 中显示")
                                    .accessibilityLabel("在 Finder 中显示项目")
                                }
                            }
                            if let parentID = project.parentProjectID {
                                GridRow {
                                    fieldLabel("父项目")
                                    Text(parentName(parentID))
                                }
                            }
                            GridRow {
                                fieldLabel("显示名称")
                                TextField("留空时使用目录名", text: $displayName)
                                    .accessibilityIdentifier("project-display-name")
                            }
                            GridRow {
                                fieldLabel("标签")
                                TextField("使用逗号分隔", text: $tagText)
                                    .accessibilityIdentifier("project-tags")
                            }
                            GridRow {
                                fieldLabel("默认编辑器")
                                Picker("默认编辑器", selection: $editorBundleIdentifier) {
                                    Text("继承全局设置").tag(String?.none)
                                    ForEach(model.data.editors) { editor in
                                        Text(editor.name).tag(Optional(editor.bundleIdentifier))
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Markdown 编辑")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("预览").font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                            }
                            HStack(spacing: 0) {
                                TextEditor(text: $description)
                                    .font(.body.monospaced())
                                    .frame(maxWidth: .infinity, minHeight: 230)
                                    .accessibilityLabel("自定义说明 Markdown 编辑")
                                    .accessibilityIdentifier("project-description")
                                Divider()
                                ScrollView {
                                    LimitedMarkdownText(markdown: description)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 230)
                                .accessibilityLabel("自定义说明预览")
                            }
                            HStack {
                                Text("支持受限 Markdown；不会加载远程图片或执行 HTML。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(description.count) / 10,000")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(isDescriptionTooLong ? .red : .secondary)
                            }
                        }
                    } label: {
                        Text("自定义说明")
                    }
                }
                .padding(16)
            }

            Divider()
            HStack {
                Spacer()
                Button("取消") {
                    if hasChanges { showingDiscardConfirmation = true }
                    else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isDescriptionTooLong)
                    .accessibilityIdentifier("project-save")
            }
            .padding(12)
        }
        .frame(width: 560, height: 480)
        .background(WindowCloseGuard(
            shouldPreventClose: { hasChanges && !allowWindowClose },
            onCloseAttempt: { showingDiscardConfirmation = true }
        ))
        .confirmationDialog("放弃未保存的更改？", isPresented: $showingDiscardConfirmation) {
            Button("放弃更改", role: .destructive) {
                allowWindowClose = true
                DispatchQueue.main.async { dismiss() }
            }
            Button("继续编辑", role: .cancel) {}
        }
        .onDisappear {
            model.editingProjectID = nil
            SearchWindowCoordinator.shared.show(model: model)
        }
    }

    private var hasChanges: Bool {
        displayName != (project.displayName ?? "")
            || description != project.customDescription
            || tags != project.tags
            || editorBundleIdentifier != project.defaultEditorBundleIdentifier
    }

    private var tags: [String] {
        tagText.split(separator: ",").map(String.init).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private var isDescriptionTooLong: Bool { description.count > 10_000 }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(width: 76, alignment: .trailing)
    }

    private func parentName(_ parentID: String) -> String {
        model.data.projects.first(where: { $0.id == parentID })?.name
            ?? URL(fileURLWithPath: parentID).lastPathComponent
    }

    private func save() {
        allowWindowClose = true
        model.saveProjectMetadata(
            projectID: project.id,
            displayName: displayName,
            description: description,
            tags: tags,
            editorBundleIdentifier: editorBundleIdentifier
        )
        dismiss()
    }
}

private struct WindowCloseGuard: NSViewRepresentable {
    let shouldPreventClose: () -> Bool
    let onCloseAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldPreventClose: shouldPreventClose, onCloseAttempt: onCloseAttempt)
    }

    func makeNSView(context: Context) -> NSView {
        let view = WindowAttachmentView()
        view.onWindowChange = { window in context.coordinator.attach(to: window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.shouldPreventClose = shouldPreventClose
        context.coordinator.onCloseAttempt = onCloseAttempt
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var shouldPreventClose: () -> Bool
        var onCloseAttempt: () -> Void
        private weak var window: NSWindow?
        private weak var closeButton: NSButton?
        private weak var originalCloseTarget: AnyObject?
        private var originalCloseAction: Selector?
        private var keyMonitor: Any?

        init(shouldPreventClose: @escaping () -> Bool, onCloseAttempt: @escaping () -> Void) {
            self.shouldPreventClose = shouldPreventClose
            self.onCloseAttempt = onCloseAttempt
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            detach()
            self.window = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            if let button = window.standardWindowButton(.closeButton) {
                closeButton = button
                originalCloseTarget = button.target
                originalCloseAction = button.action
                button.target = self
                button.action = #selector(attemptClose)
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
                guard
                    let self,
                    let window,
                    window.isKeyWindow,
                    event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                    event.charactersIgnoringModifiers?.lowercased() == "w"
                else { return event }
                self.attemptClose()
                return nil
            }
        }

        func detach() {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = nil
            restoreCloseButton()
            window = nil
            closeButton = nil
            originalCloseTarget = nil
            originalCloseAction = nil
        }

        @objc private func attemptClose() {
            if shouldPreventClose() {
                onCloseAttempt()
                return
            }
            restoreCloseButton()
            window?.performClose(nil)
        }

        private func restoreCloseButton() {
            guard let closeButton, closeButton.target === self else { return }
            closeButton.target = originalCloseTarget
            closeButton.action = originalCloseAction
        }
    }
}

private final class WindowAttachmentView: NSView {
    var onWindowChange: (NSWindow?) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange(window)
    }
}
