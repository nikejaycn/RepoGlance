import Foundation

actor ToolboxSessionStore {
    private let storageURL: URL
    private let fileManager: FileManager

    init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageURL = base
                .appendingPathComponent("RepoGlance", isDirectory: true)
                .appendingPathComponent("toolbox-sessions.json")
        }
    }

    func load() throws -> ToolboxSessionSnapshot? {
        guard fileManager.fileExists(atPath: storageURL.path) else { return nil }
        return try JSONDecoder().decode(ToolboxSessionSnapshot.self, from: Data(contentsOf: storageURL))
    }

    func save(_ snapshot: ToolboxSessionSnapshot) throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: storageURL, options: .atomic)
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        try fileManager.removeItem(at: storageURL)
    }

    func storedSize() -> Int64 {
        guard fileManager.fileExists(atPath: storageURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: storageURL.path),
              let size = attributes[.size] as? NSNumber
        else { return 0 }
        return size.int64Value
    }
}
