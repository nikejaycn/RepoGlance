import Combine
import Foundation

@MainActor
final class ToolboxModel: ObservableObject {
    static let maximumPersistedTextBytes = 1_000_000

    @Published var selectedTool: DeveloperToolID = .qrCode
    @Published var searchQuery = ""
    @Published var qrText = "" { didSet { contentDidChange() } }
    @Published var encodingInput = "" { didSet { contentDidChange() } }
    @Published var timestampInput = "" { didSet { contentDidChange() } }
    @Published var timestampDate = Date() { didSet { contentDidChange() } }
    @Published var jsonInput = "" { didSet { contentDidChange() } }
    @Published var uuidResults: [String] = [] { didSet { contentDidChange() } }
    @Published var hashInput = "" { didSet { contentDidChange() } }
    @Published private(set) var storedSize: Int64 = 0
    @Published private(set) var oversizedTools: Set<DeveloperToolID> = []
    @Published var persistenceError: String?

    private let store: ToolboxSessionStore
    private var restoreEnabled = false
    private var saveTask: Task<Void, Never>?
    private var isApplyingSnapshot = false

    init(store: ToolboxSessionStore = ToolboxSessionStore()) {
        self.store = store
    }

    func start(preferences: ToolboxPreferences) async {
        selectedTool = preferences.lastSelectedToolID
        restoreEnabled = preferences.restoreLastContent
        guard restoreEnabled else {
            try? await store.clear()
            storedSize = 0
            return
        }
        do {
            if let snapshot = try await store.load() { apply(snapshot) }
            storedSize = await store.storedSize()
        } catch {
            persistenceError = "无法恢复工具内容：\(error.localizedDescription)"
        }
    }

    func setRestoreEnabled(_ enabled: Bool) async {
        restoreEnabled = enabled
        saveTask?.cancel()
        if enabled {
            await persistNow()
        } else {
            do {
                try await store.clear()
                storedSize = 0
            } catch {
                persistenceError = "无法删除已保存的工具内容：\(error.localizedDescription)"
            }
        }
    }

    func clearAllContent() async {
        saveTask?.cancel()
        isApplyingSnapshot = true
        qrText = ""
        encodingInput = ""
        timestampInput = ""
        timestampDate = Date()
        jsonInput = ""
        uuidResults = []
        hashInput = ""
        oversizedTools = []
        isApplyingSnapshot = false
        do {
            if restoreEnabled { try await store.save(ToolboxSessionSnapshot()) }
            else { try await store.clear() }
            storedSize = await store.storedSize()
        } catch {
            persistenceError = "无法清除工具内容：\(error.localizedDescription)"
        }
    }

    func clearCurrentTool() {
        switch selectedTool {
        case .qrCode: qrText = ""
        case .encoding: encodingInput = ""
        case .timestamp:
            timestampInput = ""
            timestampDate = Date()
        case .json: jsonInput = ""
        case .uuid: uuidResults = []
        case .hash: hashInput = ""
        }
    }

    func windowWillClose() async {
        if restoreEnabled { await persistNow() }
        else { await clearAllContent() }
    }

    func persistNow() async {
        guard restoreEnabled else { return }
        saveTask?.cancel()
        let snapshot = makeSnapshot()
        do {
            try await store.save(snapshot)
            storedSize = await store.storedSize()
        } catch {
            persistenceError = "无法保存工具内容：\(error.localizedDescription)"
        }
    }

    private func contentDidChange() {
        guard !isApplyingSnapshot else { return }
        refreshOversizedTools()
        guard restoreEnabled else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    private func makeSnapshot() -> ToolboxSessionSnapshot {
        ToolboxSessionSnapshot(
            qrText: persistable(qrText, tool: .qrCode),
            encodingInput: persistable(encodingInput, tool: .encoding),
            timestampInput: persistable(timestampInput, tool: .timestamp),
            timestampDate: timestampDate,
            jsonInput: persistable(jsonInput, tool: .json),
            uuidResults: uuidResults,
            hashInput: persistable(hashInput, tool: .hash)
        )
    }

    private func persistable(_ value: String, tool: DeveloperToolID) -> String {
        value.utf8.count <= Self.maximumPersistedTextBytes ? value : ""
    }

    private func apply(_ snapshot: ToolboxSessionSnapshot) {
        isApplyingSnapshot = true
        qrText = snapshot.qrText
        encodingInput = snapshot.encodingInput
        timestampInput = snapshot.timestampInput
        timestampDate = snapshot.timestampDate
        jsonInput = snapshot.jsonInput
        uuidResults = snapshot.uuidResults
        hashInput = snapshot.hashInput
        isApplyingSnapshot = false
        refreshOversizedTools()
    }

    private func refreshOversizedTools() {
        var result: Set<DeveloperToolID> = []
        if qrText.utf8.count > Self.maximumPersistedTextBytes { result.insert(.qrCode) }
        if encodingInput.utf8.count > Self.maximumPersistedTextBytes { result.insert(.encoding) }
        if timestampInput.utf8.count > Self.maximumPersistedTextBytes { result.insert(.timestamp) }
        if jsonInput.utf8.count > Self.maximumPersistedTextBytes { result.insert(.json) }
        if hashInput.utf8.count > Self.maximumPersistedTextBytes { result.insert(.hash) }
        oversizedTools = result
    }
}
