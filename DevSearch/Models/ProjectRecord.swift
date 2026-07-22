import Foundation

enum ProjectAvailability: String, Codable, Sendable {
    case available
    case missing
    case volumeOffline
}

struct ProjectRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String { canonicalPath }

    let canonicalPath: String
    let directoryName: String
    var displayName: String?
    var scanRootPath: String
    var parentProjectID: String?
    var readmePath: String?
    var readmeExcerpt: String?
    var readmeWasTruncated: Bool
    var customDescription: String
    var tags: [String]
    var isFavorite: Bool
    var defaultEditorBundleIdentifier: String?
    var firstSeenAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var availability: ProjectAvailability

    var name: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? directoryName : trimmed
    }

    var isNested: Bool { parentProjectID != nil }

    init(
        canonicalPath: String,
        directoryName: String,
        displayName: String? = nil,
        scanRootPath: String,
        parentProjectID: String? = nil,
        readmePath: String? = nil,
        readmeExcerpt: String? = nil,
        readmeWasTruncated: Bool = false,
        customDescription: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        defaultEditorBundleIdentifier: String? = nil,
        firstSeenAt: Date = .now,
        updatedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        availability: ProjectAvailability = .available
    ) {
        self.canonicalPath = canonicalPath
        self.directoryName = directoryName
        self.displayName = displayName
        self.scanRootPath = scanRootPath
        self.parentProjectID = parentProjectID
        self.readmePath = readmePath
        self.readmeExcerpt = readmeExcerpt
        self.readmeWasTruncated = readmeWasTruncated
        self.customDescription = customDescription
        self.tags = tags
        self.isFavorite = isFavorite
        self.defaultEditorBundleIdentifier = defaultEditorBundleIdentifier
        self.firstSeenAt = firstSeenAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.availability = availability
    }
}

extension ProjectRecord {
    private enum CodingKeys: String, CodingKey {
        case canonicalPath, directoryName, displayName, scanRootPath, parentProjectID
        case readmePath, readmeExcerpt, readmeWasTruncated, customDescription, tags
        case isFavorite, defaultEditorBundleIdentifier, firstSeenAt, updatedAt
        case lastOpenedAt, availability
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let path = try values.decode(String.self, forKey: .canonicalPath)
        canonicalPath = path
        directoryName = try values.decodeIfPresent(String.self, forKey: .directoryName)
            ?? URL(fileURLWithPath: path).lastPathComponent
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName)
        scanRootPath = try values.decodeIfPresent(String.self, forKey: .scanRootPath) ?? path
        parentProjectID = try values.decodeIfPresent(String.self, forKey: .parentProjectID)
        readmePath = try values.decodeIfPresent(String.self, forKey: .readmePath)
        readmeExcerpt = try values.decodeIfPresent(String.self, forKey: .readmeExcerpt)
        readmeWasTruncated = try values.decodeIfPresent(Bool.self, forKey: .readmeWasTruncated) ?? false
        customDescription = try values.decodeIfPresent(String.self, forKey: .customDescription) ?? ""
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try values.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        defaultEditorBundleIdentifier = try values.decodeIfPresent(String.self, forKey: .defaultEditorBundleIdentifier)
        firstSeenAt = try values.decodeIfPresent(Date.self, forKey: .firstSeenAt) ?? .now
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? firstSeenAt
        lastOpenedAt = try values.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        availability = try values.decodeIfPresent(ProjectAvailability.self, forKey: .availability) ?? .available
    }
}
