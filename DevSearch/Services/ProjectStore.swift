import Foundation

actor ProjectStore {
    private let storageURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageURL = base
                .appendingPathComponent("DevSearch", isDirectory: true)
                .appendingPathComponent("data.json", isDirectory: false)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() throws -> AppData {
        guard fileManager.fileExists(atPath: storageURL.path) else { return AppData() }
        return try decoder.decode(AppData.self, from: Data(contentsOf: storageURL))
    }

    func save(_ data: AppData) throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try encoder.encode(data)
        try encoded.write(to: storageURL, options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        try fileManager.removeItem(at: storageURL)
    }
}
