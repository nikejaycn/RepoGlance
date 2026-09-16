@preconcurrency import AppKit
import Combine
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    let toolbox: ToolboxModel
    @Published private(set) var data = AppData() {
        didSet { refreshProjectSearch() }
    }
    @Published var query = "" {
        didSet { scheduleProjectSearch() }
    }
    @Published var clipboardQuery = ""
    @Published var quickPanelMode: QuickPanelMode = .projects
    @Published var selectedProjectID: String?
    @Published var selectedClipboardItemID: UUID?
    @Published private(set) var searchMatches: [SearchMatch] = []
    @Published private(set) var appliedProjectQuery = ""
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredCount = 0
    @Published private(set) var scanIssues: [ScanIssue] = []
    @Published var presentedError: String?
    @Published var editingProjectID: String?

    private let store: ProjectStore
    private let scanner: GitRepositoryScanner
    private let editorService: EditorService
    private let fileSystemMonitor: FileSystemMonitor
    private let hotKeyManager: GlobalHotKeyManager
    private let clipboardMonitor: ClipboardMonitor
    private let projectSearchDebouncer: Debouncer
    private var scanTask: Task<Void, Never>?
    private var incrementalScanTask: Task<Void, Never>?
    private var periodicScanTask: Task<Void, Never>?
    private var persistenceTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        store: ProjectStore? = nil,
        scanner: GitRepositoryScanner = GitRepositoryScanner(),
        editorService: EditorService = EditorService(),
        fileSystemMonitor: FileSystemMonitor = FileSystemMonitor(),
        hotKeyManager: GlobalHotKeyManager = GlobalHotKeyManager(),
        clipboardMonitor: ClipboardMonitor = ClipboardMonitor(),
        toolboxSessionStore: ToolboxSessionStore? = nil,
        projectSearchDebounce: Duration = .milliseconds(180)
    ) {
        self.toolbox = ToolboxModel(
            store: toolboxSessionStore ?? ToolboxSessionStore(storageURL: Self.debugToolboxStorageURL)
        )
        self.store = store ?? ProjectStore(storageURL: Self.debugStorageURL)
        self.scanner = scanner
        self.editorService = editorService
        self.fileSystemMonitor = fileSystemMonitor
        self.hotKeyManager = hotKeyManager
        self.clipboardMonitor = clipboardMonitor
        self.projectSearchDebouncer = Debouncer(delay: projectSearchDebounce)
        refreshProjectSearch()
    }

    var indexedProjects: [ProjectRecord] {
        data.projects.filter { !isExcludedFromIndex($0.canonicalPath) }
    }

    var visibleProjects: [ProjectRecord] {
        searchMatches.map(\.project)
    }

    var isProjectSearchPending: Bool {
        normalizedSearchQuery(query) != normalizedSearchQuery(appliedProjectQuery)
    }

    var visibleClipboardItems: [ClipboardItem] {
        ClipboardSearchService.search(data.clipboardItems, query: clipboardQuery)
    }

    var favoriteProjects: [ProjectRecord] {
        indexedProjects
            .filter { $0.isFavorite && $0.availability != .missing }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(5)
            .map { $0 }
    }

    var recentProjects: [ProjectRecord] {
        let favoriteIDs = Set(favoriteProjects.map(\.id))
        return indexedProjects
            .filter { $0.lastOpenedAt != nil && !favoriteIDs.contains($0.id) && $0.availability != .missing }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    var selectedProject: ProjectRecord? {
        guard let selectedProjectID else { return visibleProjects.first }
        return data.projects.first { $0.id == selectedProjectID }
    }

    func flushProjectSearch() {
        projectSearchDebouncer.cancel()
        applyProjectSearch(query)
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        do {
            data = try await store.load()
        } catch {
            presentedError = "无法读取本地索引：\(error.localizedDescription)"
        }

        mergeDiscoveredEditors()
        validateKnownPaths()
#if DEBUG
        applyDebugLaunchArguments()
#endif
        await toolbox.start(preferences: data.toolboxPreferences)
        configureAutomaticScanning()
        configureGlobalShortcut()
        configureClipboardMonitoring()
        if !data.scanRoots.isEmpty { startScan() }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-search") {
            // UI acceptance builds need a regular app activation policy so the
            // auxiliary search panel is visible to macOS accessibility tools.
            // Release builds remain menu-bar-only through LSUIElement.
            NSApp.setActivationPolicy(.regular)
            Task { @MainActor [weak self] in
                while !NSApp.isRunning, !Task.isCancelled {
                    await Task.yield()
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard let self else { return }
                SearchWindowCoordinator.shared.show(model: self)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--show-clipboard") {
            NSApp.setActivationPolicy(.regular)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self else { return }
                SearchWindowCoordinator.shared.show(model: self, mode: .clipboard)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--show-toolbox") {
            NSApp.setActivationPolicy(.regular)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self else { return }
                ToolboxWindowCoordinator.shared.show(model: self)
            }
        }
#endif
    }

    func addScanRoot(_ url: URL) {
        let path = PathNormalizer.canonicalPath(for: url)
        guard !data.scanRoots.contains(where: { $0.canonicalPath == path }) else { return }
        data.scanRoots.append(ScanRoot(canonicalPath: path, displayPath: url.path))
        persist()
        configureAutomaticScanning()
        startScan()
    }

    func chooseAndAddScanRoot() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "选择扫描目录"
            panel.message = "RepoGlance 会发现此文件夹内的 Git 仓库和嵌套仓库。"
            panel.prompt = "添加"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = true
            guard await NativePresentation.present(panel) == .OK else { return }
            panel.urls.forEach { addScanRoot($0) }
        }
    }

    func removeScanRoot(_ root: ScanRoot, removeMetadata: Bool = false) {
        data.scanRoots.removeAll { $0.id == root.id }
        if removeMetadata {
            data.projects.removeAll { $0.scanRootPath == root.canonicalPath }
        } else {
            for index in data.projects.indices where data.projects[index].scanRootPath == root.canonicalPath {
                data.projects[index].availability = .missing
            }
        }
        persist()
        configureAutomaticScanning()
    }

    func updateScanRoot(_ root: ScanRoot) {
        guard let index = data.scanRoots.firstIndex(where: { $0.id == root.id }) else { return }
        data.scanRoots[index] = root
        persist()
        configureAutomaticScanning()
    }

    func chooseReplacement(for root: ScanRoot) {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "重新选择扫描目录"
            panel.message = "选择原目录以恢复访问权限，或选择新的项目根目录。"
            panel.prompt = "选择"
            panel.directoryURL = URL(fileURLWithPath: root.displayPath, isDirectory: true)
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }

            let newPath = PathNormalizer.canonicalPath(for: url)
            guard newPath == root.canonicalPath || !data.scanRoots.contains(where: { $0.canonicalPath == newPath }) else {
                presentedError = "该目录已经在扫描列表中。"
                return
            }
            data.scanRoots.removeAll { $0.id == root.id }
            data.scanRoots.append(ScanRoot(
                canonicalPath: newPath,
                displayPath: url.path,
                isEnabled: root.isEnabled,
                scanHiddenDirectories: root.scanHiddenDirectories,
                maximumDepth: root.maximumDepth,
                ignoredDirectoryNames: root.ignoredDirectoryNames
            ))
            persist()
            configureAutomaticScanning()
            startScan()
        }
    }

    func chooseAndAddEditor() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "选择编辑器"
            panel.prompt = "添加"
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.application]
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }

            let bundle = Bundle(url: url)
            guard let identifier = bundle?.bundleIdentifier else {
                presentedError = "所选应用没有有效的 Bundle Identifier。"
                return
            }
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let editor = EditorDefinition(
                id: identifier,
                name: name,
                bundleIdentifier: identifier,
                applicationPath: url.path,
                isManuallyAdded: true
            )
            data.editors.removeAll { $0.id == editor.id }
            data.editors.append(editor)
            data.editors.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            persist()
        }
    }

    func removeEditor(_ editor: EditorDefinition) {
        guard editor.isManuallyAdded else { return }
        data.editors.removeAll { $0.id == editor.id }
        if data.preferences.defaultEditorBundleIdentifier == editor.bundleIdentifier {
            data.preferences.defaultEditorBundleIdentifier = nil
        }
        for index in data.projects.indices where data.projects[index].defaultEditorBundleIdentifier == editor.bundleIdentifier {
            data.projects[index].defaultEditorBundleIdentifier = nil
        }
        persist()
    }

    func startScan() {
        scanTask?.cancel()
        isScanning = true
        discoveredCount = 0
        let roots = data.scanRoots
        let exclusions = data.exclusionRules

        scanTask = Task { [weak self, scanner] in
            guard let self else { return }
            let result = await scanner.scan(
                roots: roots,
                exclusions: exclusions,
                progress: { count in
                    await MainActor.run { self.discoveredCount = count }
                },
                onDiscovery: { project in
                    await MainActor.run { self.applyIncrementalDiscovery(project) }
                }
            )
            guard !Task.isCancelled else {
                self.isScanning = false
                return
            }
            self.applyScanResult(result, scannedRoots: roots)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        persist()
    }

    func open(_ project: ProjectRecord, editorBundleIdentifier: String? = nil) async {
        let configuredEditor = editorBundleIdentifier
            ?? project.defaultEditorBundleIdentifier
            ?? data.preferences.defaultEditorBundleIdentifier
        if let configuredEditor, editorService.applicationPath(for: configuredEditor) == nil {
            await open(
                project,
                target: await chooseOpeningTarget(
                    informativeText: "之前选择的编辑器已不可用。请选择另一个编辑器，或先在 Finder 中查看项目。"
                )
            )
            return
        }
        let openingTarget: OpeningTarget
        if let configuredEditor { openingTarget = .editor(configuredEditor) }
        else { openingTarget = await chooseOpeningTarget() }
        await open(project, target: openingTarget)
    }

    func chooseAndOpen(_ project: ProjectRecord) async {
        await open(project, target: chooseOpeningTarget())
    }

    private func open(_ project: ProjectRecord, target: OpeningTarget) async {
        guard target != .cancel else { return }
        let presentingWindow = NSApp.keyWindow
        let editor: String? = switch target {
        case let .editor(bundleIdentifier): bundleIdentifier
        case .finder: nil
        case .cancel: nil
        }
        do {
            try await editorService.open(project: project, editorBundleIdentifier: editor)
            if let index = data.projects.firstIndex(where: { $0.id == project.id }) {
                data.projects[index].lastOpenedAt = .now
                persist()
            }
            if data.preferences.closeAfterOpening {
                PreviewPanelCoordinator.shared.hideImmediately()
                presentingWindow?.orderOut(nil)
            }
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func revealInFinder(_ project: ProjectRecord) {
        editorService.revealInFinder(project)
    }

    func openInTerminal(_ project: ProjectRecord) async {
        do {
            try await editorService.openInTerminal(
                project,
                terminalBundleIdentifier: data.preferences.terminalBundleIdentifier
            )
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func copyPath(_ project: ProjectRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(project.canonicalPath, forType: .string)
    }

    func setClipboardHistoryEnabled(_ enabled: Bool) {
        data.preferences.clipboardHistoryEnabled = enabled
        persist()
        configureClipboardMonitoring()
    }

    func copyClipboardItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        recordClipboardText(item.text)
    }

    func removeClipboardItem(_ item: ClipboardItem) {
        data.clipboardItems.removeAll { $0.id == item.id }
        persist()
    }

    func restoreClipboardItem(_ item: ClipboardItem, at index: Int) {
        guard !data.clipboardItems.contains(where: { $0.id == item.id }) else { return }
        data.clipboardItems.insert(item, at: min(max(0, index), data.clipboardItems.count))
        data.clipboardItems = Array(
            data.clipboardItems.prefix(max(1, data.preferences.clipboardHistoryLimit))
        )
        persist()
    }

    func resetQuickPanelSession() {
        query = ""
        clipboardQuery = ""
        selectedProjectID = nil
        selectedClipboardItemID = nil
    }

    func clearClipboardHistory() {
        data.clipboardItems = []
        persist()
    }

    func openFullReadme(_ project: ProjectRecord) {
        guard let readmePath = project.readmePath else { return }
        let editor = project.defaultEditorBundleIdentifier
            ?? data.preferences.defaultEditorBundleIdentifier
        Task { [weak self, editorService] in
            do {
                try await editorService.openFile(
                    URL(fileURLWithPath: readmePath),
                    editorBundleIdentifier: editor
                )
            } catch {
                self?.presentedError = "无法打开完整 README：\(error.localizedDescription)"
            }
        }
    }

    func toggleFavorite(_ project: ProjectRecord) {
        guard let index = data.projects.firstIndex(where: { $0.id == project.id }) else { return }
        data.projects[index].isFavorite.toggle()
        persist()
    }

    func saveProjectMetadata(
        projectID: String,
        displayName: String,
        description: String,
        tags: [String],
        editorBundleIdentifier: String?
    ) {
        guard let index = data.projects.firstIndex(where: { $0.id == projectID }) else { return }
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        data.projects[index].displayName = cleanName.isEmpty ? nil : cleanName
        data.projects[index].customDescription = description
        data.projects[index].tags = Array(Set(tags.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
        data.projects[index].defaultEditorBundleIdentifier = editorBundleIdentifier
        data.projects[index].updatedAt = .now
        persist()
        objectWillChange.send()
    }

    func exclude(_ project: ProjectRecord, includingDescendants: Bool) {
        let rule = ExclusionRule(canonicalPath: project.canonicalPath, includesDescendants: includingDescendants)
        data.exclusionRules.removeAll { $0.canonicalPath == project.canonicalPath }
        data.exclusionRules.append(rule)
        persist()
        startScan()
    }

    func isExcludedFromIndex(_ path: String) -> Bool {
        data.exclusionRules.contains { rule in
            path == rule.canonicalPath
                || (rule.includesDescendants && PathNormalizer.isDescendant(path, of: rule.canonicalPath))
        }
    }

    func restoreExclusion(_ rule: ExclusionRule) {
        data.exclusionRules.removeAll { $0.id == rule.id }
        persist()
        startScan()
    }

    func setDefaultEditor(_ bundleIdentifier: String?) {
        data.preferences.defaultEditorBundleIdentifier = bundleIdentifier
        persist()
    }

    func updatePreferences(_ preferences: AppPreferences) {
        let scanIntervalChanged = data.preferences.automaticScanIntervalMinutes
            != preferences.automaticScanIntervalMinutes
        let clipboardChanged = data.preferences.clipboardHistoryEnabled
            != preferences.clipboardHistoryEnabled
        data.preferences = preferences
        data.clipboardItems = Array(
            data.clipboardItems.prefix(max(1, preferences.clipboardHistoryLimit))
        )
        persist()
        configureGlobalShortcut()
        if clipboardChanged { configureClipboardMonitoring() }
        if scanIntervalChanged { configureAutomaticScanning() }
    }

    func selectTool(_ tool: DeveloperToolID) {
        guard toolbox.selectedTool != tool else { return }
        toolbox.selectedTool = tool
        var preferences = data.toolboxPreferences
        preferences.lastSelectedToolID = tool
        data.toolboxPreferences = preferences
        persist()
    }

    func toggleFavoriteTool(_ tool: DeveloperToolID) {
        var preferences = data.toolboxPreferences
        if preferences.favoriteToolIDs.contains(tool) {
            preferences.favoriteToolIDs.remove(tool)
        } else {
            preferences.favoriteToolIDs.insert(tool)
        }
        data.toolboxPreferences = preferences
        persist()
    }

    func updateToolboxPreferences(_ preferences: ToolboxPreferences) {
        let shortcutChanged = data.toolboxPreferences.globalShortcutEnabled != preferences.globalShortcutEnabled
            || data.toolboxPreferences.globalShortcut != preferences.globalShortcut
        data.toolboxPreferences = preferences
        persist()
        if shortcutChanged { configureGlobalShortcut() }
    }

    func setToolboxRestoreEnabled(_ enabled: Bool) async {
        var preferences = data.toolboxPreferences
        preferences.restoreLastContent = enabled
        data.toolboxPreferences = preferences
        persist()
        await toolbox.setRestoreEnabled(enabled)
    }

    func clearToolboxContent() async {
        await toolbox.clearAllContent()
    }

    func copyToolboxText(_ text: String) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.AutoGeneratedType"))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }

    func copyToolboxImage(_ image: CGImage) {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let tiff = representation.tiffRepresentation else { return }
        let item = NSPasteboardItem()
        item.setData(tiff, forType: .tiff)
        item.setData(Data(), forType: .init("org.nspasteboard.AutoGeneratedType"))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }

    func toolboxClipboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            data.preferences.launchAtLogin = enabled
            persist()
        } catch {
            presentedError = "无法更新登录项：\(error.localizedDescription)"
        }
    }

    func chooseAndRelocate(_ project: ProjectRecord) {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "重新定位项目"
            panel.message = "选择项目新的 Git 仓库目录。"
            panel.prompt = "重新定位"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }

            Task { [self, scanner] in
                guard await scanner.isGitRepository(at: url) else {
                    self.presentedError = "所选目录不是有效的 Git 仓库。"
                    return
                }
                let newPath = PathNormalizer.canonicalPath(for: url)
                guard let root = self.data.scanRoots
                    .filter({ newPath == $0.canonicalPath || PathNormalizer.isDescendant(newPath, of: $0.canonicalPath) })
                    .max(by: { $0.canonicalPath.count < $1.canonicalPath.count })
                else {
                    self.presentedError = "新位置不在已配置的扫描目录内，请先添加包含它的扫描目录。"
                    return
                }

                let oldTree = self.data.projects.filter {
                    $0.id == project.id || PathNormalizer.isDescendant($0.id, of: project.id)
                }
                var mappings: [(old: ProjectRecord, newPath: String)] = []
                for old in oldTree {
                    let suffix = String(old.canonicalPath.dropFirst(project.canonicalPath.count))
                    let candidatePath = newPath + suffix
                    let candidateURL = URL(fileURLWithPath: candidatePath, isDirectory: true)
                    if await scanner.isGitRepository(at: candidateURL) {
                        mappings.append((old, candidatePath))
                    }
                }

                let unmatchedCount = oldTree.count - mappings.count
                if mappings.count > 1 || unmatchedCount > 0 {
                    let alert = NSAlert()
                    alert.messageText = "同时迁移嵌套仓库？"
                    var details = "将迁移父项目和 \(max(0, mappings.count - 1)) 个匹配的子仓库。"
                    if unmatchedCount > 0 {
                        details += " \(unmatchedCount) 个未匹配的子仓库将保留为路径失效。"
                    }
                    alert.informativeText = details
                    alert.addButton(withTitle: "继续")
                    alert.addButton(withTitle: "取消")
                    guard await NativePresentation.present(alert) == .alertFirstButtonReturn else { return }
                }

                let migratedOldIDs = Set(mappings.map { $0.old.id })
                let destinationIDs = Set(mappings.map { $0.newPath })
                let unaffectedPaths = self.data.projects.compactMap { record -> String? in
                    guard !migratedOldIDs.contains(record.id), !destinationIDs.contains(record.id) else { return nil }
                    return record.id
                }
                let knownDestinationPaths = unaffectedPaths + Array(destinationIDs)

                let relocatedRecords = mappings.map { mapping -> ProjectRecord in
                    let destinationURL = URL(fileURLWithPath: mapping.newPath, isDirectory: true)
                    let readme = ReadmeService.readme(in: destinationURL)
                    let destinationRoot = self.data.scanRoots
                        .filter {
                            mapping.newPath == $0.canonicalPath
                                || PathNormalizer.isDescendant(mapping.newPath, of: $0.canonicalPath)
                        }
                        .max(by: { $0.canonicalPath.count < $1.canonicalPath.count })
                        ?? root
                    let parent = knownDestinationPaths
                        .filter { PathNormalizer.isDescendant(mapping.newPath, of: $0) }
                        .max(by: { $0.count < $1.count })
                    return ProjectRecord(
                        canonicalPath: mapping.newPath,
                        directoryName: destinationURL.lastPathComponent,
                        displayName: mapping.old.displayName,
                        scanRootPath: destinationRoot.canonicalPath,
                        parentProjectID: parent,
                        readmePath: readme?.url.path,
                        readmeExcerpt: readme?.excerpt,
                        readmeWasTruncated: readme?.wasTruncated ?? false,
                        customDescription: mapping.old.customDescription,
                        tags: mapping.old.tags,
                        isFavorite: mapping.old.isFavorite,
                        defaultEditorBundleIdentifier: mapping.old.defaultEditorBundleIdentifier,
                        firstSeenAt: mapping.old.firstSeenAt,
                        updatedAt: .now,
                        lastOpenedAt: mapping.old.lastOpenedAt
                    )
                }

                // A background scan may discover destinations before the user
                // confirms relocation. Replace those transient records while
                // preserving metadata from every matching record in the old tree.
                self.data.projects.removeAll {
                    migratedOldIDs.contains($0.id) || destinationIDs.contains($0.id)
                }
                self.data.projects.append(contentsOf: relocatedRecords)

                // Unmatched descendants remain as missing records, but must not
                // reference a parent path that was successfully migrated away.
                let remainingPaths = Set(self.data.projects.map(\.id))
                for index in self.data.projects.indices
                where oldTree.contains(where: { $0.id == self.data.projects[index].id }) {
                    let recordPath = self.data.projects[index].id
                    self.data.projects[index].parentProjectID = remainingPaths
                        .filter { PathNormalizer.isDescendant(recordPath, of: $0) }
                        .max(by: { $0.count < $1.count })
                }
                self.persist()
                self.startScan()
            }
        }
    }

    func deleteProjectRecord(_ project: ProjectRecord) {
        data.projects.removeAll { $0.id == project.id }
        persist()
    }

    func exportCustomData() {
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.title = "导出 RepoGlance 数据"
            panel.nameFieldStringValue = "DevSearch-Export.json"
            panel.allowedContentTypes = [.json]
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(data).write(to: url, options: .atomic)
            } catch {
                presentedError = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    func importCustomData() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "导入 RepoGlance 数据"
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.json]
            guard await NativePresentation.present(panel) == .OK, let url = panel.url else { return }
            let confirmation = NSAlert()
            confirmation.messageText = "导入并替换当前数据？"
            confirmation.informativeText = "当前的扫描目录、说明、标签、收藏和偏好会被所选文件替换。此操作无法撤销。"
            confirmation.alertStyle = .warning
            confirmation.addButton(withTitle: "导入并替换")
            confirmation.addButton(withTitle: "取消")
            guard await NativePresentation.present(confirmation) == .alertFirstButtonReturn else { return }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                data = try decoder.decode(AppData.self, from: Data(contentsOf: url))
                mergeDiscoveredEditors()
                validateKnownPaths()
                configureAutomaticScanning()
                configureGlobalShortcut()
                configureClipboardMonitoring()
                persist()
                Task { await toolbox.start(preferences: data.toolboxPreferences) }
                startScan()
            } catch {
                presentedError = "导入失败：\(error.localizedDescription)"
            }
        }
    }

    func clearAllData() async {
        scanTask?.cancel()
        await persistenceTask?.value
        persistenceTask = nil
        do {
            try await store.clear()
            data = AppData()
            await toolbox.clearAllContent()
            mergeDiscoveredEditors()
            scanIssues = []
            discoveredCount = 0
            isScanning = false
            configureAutomaticScanning()
            configureGlobalShortcut()
            configureClipboardMonitoring()
        } catch {
            presentedError = "无法清除数据：\(error.localizedDescription)"
        }
    }

    private func mergeDiscoveredEditors() {
        let discovered = editorService.discoverEditors()
        var merged = data.editors.reduce(into: [String: EditorDefinition]()) {
            $0[$1.id] = $1
        }
        for editor in discovered { merged[editor.id] = editor }
        for (id, editor) in merged where !discovered.contains(where: { $0.id == id }) {
            var refreshed = editor
            refreshed.applicationPath = editorService.applicationPath(for: editor.bundleIdentifier)
            merged[id] = refreshed
        }
        data.editors = merged.values.sorted { $0.name < $1.name }
        if data.preferences.defaultEditorBundleIdentifier == nil, data.editors.count == 1 {
            data.preferences.defaultEditorBundleIdentifier = data.editors.first?.bundleIdentifier
        }
        persist()
    }

    private func chooseOpeningTarget(
        informativeText: String = "尚未设置默认编辑器。你可以选择一个编辑器，或先在 Finder 中查看项目。"
    ) async -> OpeningTarget {
        let alert = NSAlert()
        alert.messageText = "选择打开方式"
        alert.informativeText = informativeText
        alert.alertStyle = .informational

        let availableEditors = data.editors.filter {
            editorService.applicationPath(for: $0.bundleIdentifier) != nil
        }
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26), pullsDown: false)
        for editor in availableEditors { popup.addItem(withTitle: editor.name) }
        popup.addItem(withTitle: "在 Finder 中显示")
        alert.accessoryView = popup
        alert.addButton(withTitle: "打开")
        alert.addButton(withTitle: "取消")

        guard await NativePresentation.present(alert) == .alertFirstButtonReturn else { return .cancel }
        if popup.indexOfSelectedItem < availableEditors.count {
            return .editor(availableEditors[popup.indexOfSelectedItem].bundleIdentifier)
        }
        return .finder
    }

    private func validateKnownPaths() {
        for index in data.projects.indices {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: data.projects[index].canonicalPath,
                isDirectory: &isDirectory
            )
            data.projects[index].availability = exists && isDirectory.boolValue ? .available : .missing
        }
    }

    private func applyScanResult(_ result: RepositoryScanResult, scannedRoots: [ScanRoot]) {
        data.projects = IndexMergeService.merge(
            existing: data.projects,
            scanned: result.projects,
            activeRootPaths: Set(scannedRoots.filter(\.isEnabled).map(\.canonicalPath)),
            exclusions: data.exclusionRules,
            issues: result.issues
        )
        let now = Date.now
        for index in data.scanRoots.indices where data.scanRoots[index].isEnabled {
            data.scanRoots[index].lastScanAt = now
        }
        scanIssues = result.issues
        isScanning = false
        persist()
    }

    private func applyIncrementalDiscovery(_ discovered: ProjectRecord) {
        if let index = data.projects.firstIndex(where: { $0.id == discovered.id }) {
            let old = data.projects[index]
            var merged = discovered
            merged.displayName = old.displayName
            merged.customDescription = old.customDescription
            merged.tags = old.tags
            merged.isFavorite = old.isFavorite
            merged.defaultEditorBundleIdentifier = old.defaultEditorBundleIdentifier
            merged.firstSeenAt = old.firstSeenAt
            merged.lastOpenedAt = old.lastOpenedAt
            data.projects[index] = merged
        } else {
            data.projects.append(discovered)
        }
        data.projects.sort { $0.canonicalPath.localizedStandardCompare($1.canonicalPath) == .orderedAscending }
    }

    private func scheduleProjectSearch() {
        let pendingQuery = query
        if normalizedSearchQuery(pendingQuery).isEmpty {
            projectSearchDebouncer.cancel()
            applyProjectSearch(pendingQuery)
            return
        }

        projectSearchDebouncer.schedule { [weak self] in
            guard let self, self.query == pendingQuery else { return }
            self.applyProjectSearch(pendingQuery)
        }
    }

    private func refreshProjectSearch() {
        applyProjectSearch(appliedProjectQuery)
    }

    private func applyProjectSearch(_ searchQuery: String) {
        let matches = SearchService.search(indexedProjects, query: searchQuery)
        searchMatches = matches
        appliedProjectQuery = searchQuery
    }

    private func normalizedSearchQuery(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persist() {
        let snapshot = data
        let previousTask = persistenceTask
        persistenceTask = Task { [store] in
            await previousTask?.value
            do { try await store.save(snapshot) }
            catch { await MainActor.run { self.presentedError = "无法保存本地索引：\(error.localizedDescription)" } }
        }
    }

    private func configureAutomaticScanning() {
        let paths = data.scanRoots.filter(\.isEnabled).map(\.canonicalPath)
        fileSystemMonitor.start(paths: paths) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleIncrementalScan() }
        }

        periodicScanTask?.cancel()
        let intervalMinutes = data.preferences.automaticScanIntervalMinutes
        guard intervalMinutes > 0 else {
            periodicScanTask = nil
            return
        }
        periodicScanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalMinutes * 60))
                guard !Task.isCancelled else { return }
                self?.startScan()
            }
        }
    }

    private func scheduleIncrementalScan() {
        incrementalScanTask?.cancel()
        incrementalScanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.startScan()
        }
    }

    private func configureGlobalShortcut() {
        hotKeyManager.unregister()
        if data.preferences.globalShortcutEnabled {
            let registered = hotKeyManager.register(
                shortcut: data.preferences.globalShortcut,
                id: 1
            ) { [weak self] in
                guard let self else { return }
                SearchWindowCoordinator.shared.toggle(model: self, mode: .projects)
            }
            if !registered {
                data.preferences.globalShortcutEnabled = false
                persist()
                presentedError = "快捷键 \(data.preferences.globalShortcut.displayName) 已被其他应用或系统占用，已自动关闭。请在设置中选择其他组合。"
            }
        }

        let clipboardRegistered = hotKeyManager.register(
            shortcut: .optionShiftSpace,
            id: 2
        ) { [weak self] in
            guard let self else { return }
            SearchWindowCoordinator.shared.toggle(model: self, mode: .clipboard)
        }
        if !clipboardRegistered, presentedError == nil {
            presentedError = "剪贴板快捷键 ⌥ ⇧ Space 已被其他应用或系统占用。仍可从菜单栏打开剪贴板。"
        }

        if data.toolboxPreferences.globalShortcutEnabled {
            let toolboxRegistered = hotKeyManager.register(
                shortcut: data.toolboxPreferences.globalShortcut,
                id: 3
            ) { [weak self] in
                guard let self else { return }
                ToolboxWindowCoordinator.shared.toggle(model: self)
            }
            if !toolboxRegistered {
                data.toolboxPreferences.globalShortcutEnabled = false
                persist()
                if presentedError == nil {
                    presentedError = "工具箱快捷键 \(data.toolboxPreferences.globalShortcut.displayName) 已被其他应用或系统占用，已自动关闭。"
                }
            }
        }
    }

    private func configureClipboardMonitoring() {
        guard data.preferences.clipboardHistoryEnabled else {
            clipboardMonitor.stop()
            return
        }
        clipboardMonitor.start { [weak self] text in
            self?.recordClipboardText(text)
        }
    }

    private func recordClipboardText(_ text: String) {
        guard data.preferences.clipboardHistoryEnabled else { return }
        let updated = ClipboardHistoryService.inserting(
            text,
            into: data.clipboardItems,
            limit: data.preferences.clipboardHistoryLimit
        )
        guard updated != data.clipboardItems else { return }
        data.clipboardItems = updated
        persist()
    }

#if DEBUG
    private static var debugStorageURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--test-storage"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    private static var debugToolboxStorageURL: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--toolbox-storage"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1])
        }
        guard let storageURL = debugStorageURL else { return nil }
        return storageURL.deletingPathExtension().appendingPathExtension("toolbox.json")
    }

    private func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--scan-root"), arguments.indices.contains(index + 1) {
            let url = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            let path = PathNormalizer.canonicalPath(for: url)
            if !data.scanRoots.contains(where: { $0.id == path }) {
                data.scanRoots.append(ScanRoot(canonicalPath: path, displayPath: url.path))
            }
        }
        if arguments.contains("--no-default-editor") {
            data.preferences.defaultEditorBundleIdentifier = nil
        }
    }
#else
    private static var debugStorageURL: URL? { nil }
    private static var debugToolboxStorageURL: URL? { nil }
#endif
}

private enum OpeningTarget: Equatable {
    case editor(String)
    case finder
    case cancel
}
