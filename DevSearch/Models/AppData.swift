import Foundation

struct ScanRoot: Codable, Identifiable, Hashable, Sendable {
    var id: String { canonicalPath }

    let canonicalPath: String
    var displayPath: String
    var isEnabled: Bool
    var scanHiddenDirectories: Bool
    var maximumDepth: Int
    var ignoredDirectoryNames: Set<String>
    var ignoredRelativePaths: Set<String>
    var lastScanAt: Date?

    init(
        canonicalPath: String,
        displayPath: String? = nil,
        isEnabled: Bool = true,
        scanHiddenDirectories: Bool = false,
        maximumDepth: Int = 64,
        ignoredDirectoryNames: Set<String> = ScanRoot.defaultIgnoredDirectoryNames,
        ignoredRelativePaths: Set<String> = [],
        lastScanAt: Date? = nil
    ) {
        self.canonicalPath = canonicalPath
        self.displayPath = displayPath ?? canonicalPath
        self.isEnabled = isEnabled
        self.scanHiddenDirectories = scanHiddenDirectories
        self.maximumDepth = maximumDepth
        self.ignoredDirectoryNames = ignoredDirectoryNames
        self.ignoredRelativePaths = ignoredRelativePaths
        self.lastScanAt = lastScanAt
    }

    static let defaultIgnoredDirectoryNames: Set<String> = [
        ".git", ".build", ".cache", ".derivedData", "DerivedData",
        "node_modules", "Pods", "vendor", "build", "dist"
    ]
}

struct ExclusionRule: Codable, Identifiable, Hashable, Sendable {
    var id: String { canonicalPath + (includesDescendants ? "/*" : "") }

    let canonicalPath: String
    let includesDescendants: Bool
    let createdAt: Date

    init(canonicalPath: String, includesDescendants: Bool, createdAt: Date = .now) {
        self.canonicalPath = canonicalPath
        self.includesDescendants = includesDescendants
        self.createdAt = createdAt
    }
}

struct EditorDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String
    var applicationPath: String?
    var isManuallyAdded: Bool
}

struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    var copiedAt: Date

    init(id: UUID = UUID(), text: String, copiedAt: Date = .now) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }
}

enum QuickPanelMode: String, CaseIterable, Identifiable, Sendable {
    case projects
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: "项目"
        case .clipboard: "剪贴板"
        }
    }
}

enum GlobalShortcut: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionSpace
    case optionShiftSpace
    case commandShiftSpace
    case controlOptionSpace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .optionShiftSpace: "⌥ ⇧ Space"
        case .commandShiftSpace: "⌘ ⇧ Space"
        case .controlOptionSpace: "⌃ ⌥ Space"
        }
    }
}

struct AppPreferences: Codable, Hashable, Sendable {
    var defaultEditorBundleIdentifier: String?
    var terminalBundleIdentifier: String = "com.apple.Terminal"
    var closeAfterOpening: Bool = true
    var previewDelayMilliseconds: Int = 400
    var automaticScanIntervalMinutes: Int = 15
    var launchAtLogin: Bool = false
    var globalShortcutEnabled: Bool = true
    var globalShortcut: GlobalShortcut = .optionSpace
    var clipboardHistoryEnabled: Bool = false
    var clipboardHistoryLimit: Int = 100
}

struct AppData: Codable, Sendable {
    var scanRoots: [ScanRoot] = []
    var projects: [ProjectRecord] = []
    var exclusionRules: [ExclusionRule] = []
    var editors: [EditorDefinition] = []
    var clipboardItems: [ClipboardItem] = []
    var preferences = AppPreferences()
}

extension ScanRoot {
    private enum CodingKeys: String, CodingKey {
        case canonicalPath, displayPath, isEnabled, scanHiddenDirectories
        case maximumDepth, ignoredDirectoryNames, ignoredRelativePaths, lastScanAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        canonicalPath = try values.decode(String.self, forKey: .canonicalPath)
        displayPath = try values.decodeIfPresent(String.self, forKey: .displayPath) ?? canonicalPath
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        scanHiddenDirectories = try values.decodeIfPresent(Bool.self, forKey: .scanHiddenDirectories) ?? false
        maximumDepth = try values.decodeIfPresent(Int.self, forKey: .maximumDepth) ?? 64
        ignoredDirectoryNames = try values.decodeIfPresent(Set<String>.self, forKey: .ignoredDirectoryNames)
            ?? Self.defaultIgnoredDirectoryNames
        ignoredRelativePaths = try values.decodeIfPresent(Set<String>.self, forKey: .ignoredRelativePaths) ?? []
        lastScanAt = try values.decodeIfPresent(Date.self, forKey: .lastScanAt)
    }
}

extension AppPreferences {
    private enum CodingKeys: String, CodingKey {
        case defaultEditorBundleIdentifier, terminalBundleIdentifier, closeAfterOpening
        case previewDelayMilliseconds, automaticScanIntervalMinutes
        case launchAtLogin, globalShortcutEnabled, globalShortcut
        case clipboardHistoryEnabled, clipboardHistoryLimit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        defaultEditorBundleIdentifier = try values.decodeIfPresent(String.self, forKey: .defaultEditorBundleIdentifier)
        terminalBundleIdentifier = try values.decodeIfPresent(String.self, forKey: .terminalBundleIdentifier)
            ?? "com.apple.Terminal"
        closeAfterOpening = try values.decodeIfPresent(Bool.self, forKey: .closeAfterOpening) ?? true
        previewDelayMilliseconds = try values.decodeIfPresent(Int.self, forKey: .previewDelayMilliseconds) ?? 400
        automaticScanIntervalMinutes = try values.decodeIfPresent(Int.self, forKey: .automaticScanIntervalMinutes) ?? 15
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        globalShortcutEnabled = try values.decodeIfPresent(Bool.self, forKey: .globalShortcutEnabled) ?? true
        globalShortcut = try values.decodeIfPresent(GlobalShortcut.self, forKey: .globalShortcut) ?? .optionSpace
        clipboardHistoryEnabled = try values.decodeIfPresent(Bool.self, forKey: .clipboardHistoryEnabled) ?? false
        clipboardHistoryLimit = try values.decodeIfPresent(Int.self, forKey: .clipboardHistoryLimit) ?? 100
    }
}

extension AppData {
    private enum CodingKeys: String, CodingKey {
        case scanRoots, projects, exclusionRules, editors, clipboardItems, preferences
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        scanRoots = (try values.decodeIfPresent([ScanRoot].self, forKey: .scanRoots) ?? [])
            .deduplicatedKeepingLast(by: \.id)
        projects = (try values.decodeIfPresent([ProjectRecord].self, forKey: .projects) ?? [])
            .deduplicatedKeepingLast(by: \.id)
        exclusionRules = (try values.decodeIfPresent([ExclusionRule].self, forKey: .exclusionRules) ?? [])
            .deduplicatedKeepingLast(by: \.id)
        editors = (try values.decodeIfPresent([EditorDefinition].self, forKey: .editors) ?? [])
            .deduplicatedKeepingLast(by: \.id)
        clipboardItems = (try values.decodeIfPresent([ClipboardItem].self, forKey: .clipboardItems) ?? [])
            .deduplicatedKeepingLast(by: \.id)
        preferences = try values.decodeIfPresent(AppPreferences.self, forKey: .preferences) ?? AppPreferences()
    }
}

extension Sequence {
    func deduplicatedKeepingLast<Key: Hashable>(
        by keyPath: KeyPath<Element, Key>
    ) -> [Element] {
        var result: [Element] = []
        var indexByKey: [Key: Int] = [:]

        for element in self {
            let key = element[keyPath: keyPath]
            if let index = indexByKey[key] {
                result[index] = element
            } else {
                indexByKey[key] = result.count
                result.append(element)
            }
        }
        return result
    }
}
