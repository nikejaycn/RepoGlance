import Foundation

enum DeveloperToolID: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case qrCode
    case encoding
    case timestamp
    case json
    case uuid
    case hash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qrCode: "二维码生成"
        case .encoding: "编码转换"
        case .timestamp: "时间戳换算"
        case .json: "JSON 工具"
        case .uuid: "UUID 生成"
        case .hash: "哈希摘要"
        }
    }

    var subtitle: String {
        switch self {
        case .qrCode: "将文本或 URL 生成为标准二维码"
        case .encoding: "Base64、URL、HTML 与 UTF-8 Hex 编解码"
        case .timestamp: "Unix 秒、毫秒与日期时间双向换算"
        case .json: "校验、格式化和压缩 JSON"
        case .uuid: "批量生成 UUID v4"
        case .hash: "计算文本的 MD5 与 SHA 摘要"
        }
    }

    var systemImage: String {
        switch self {
        case .qrCode: "qrcode"
        case .encoding: "arrow.left.arrow.right"
        case .timestamp: "clock.arrow.2.circlepath"
        case .json: "curlybraces"
        case .uuid: "number"
        case .hash: "number.square"
        }
    }

    var category: DeveloperToolCategory {
        switch self {
        case .qrCode, .uuid: .generation
        case .encoding, .timestamp: .conversion
        case .json: .formatting
        case .hash: .digest
        }
    }

    var searchableText: String {
        switch self {
        case .qrCode: "二维码 QR code 文本 URL 链接 图片 PNG 生成"
        case .encoding: "编码 转换 Base64 URL Percent HTML Entity UTF-8 Hex 编码 解码"
        case .timestamp: "时间戳 Unix 秒 毫秒 日期 时间 时区 ISO 8601"
        case .json: "JSON 校验 格式化 美化 压缩 minify validate"
        case .uuid: "UUID GUID v4 随机 标识符 批量"
        case .hash: "哈希 Hash 摘要 MD5 SHA-1 SHA-256 SHA-512 checksum"
        }
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return needle.isEmpty || searchableText.localizedCaseInsensitiveContains(needle)
    }
}

enum DeveloperToolCategory: String, CaseIterable, Identifiable, Sendable {
    case generation
    case conversion
    case formatting
    case digest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generation: "生成"
        case .conversion: "转换"
        case .formatting: "格式化"
        case .digest: "标识与摘要"
        }
    }
}

enum EncodingFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case base64
    case urlPercent
    case htmlEntity
    case utf8Hex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base64: "Base64"
        case .urlPercent: "URL Percent"
        case .htmlEntity: "HTML Entity"
        case .utf8Hex: "UTF-8 Hex"
        }
    }
}

enum TransformDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case encode
    case decode

    var id: String { rawValue }
    var title: String { self == .encode ? "编码" : "解码" }
    var opposite: Self { self == .encode ? .decode : .encode }
}

enum TimestampDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case timestampToDate
    case dateToTimestamp

    var id: String { rawValue }
    var title: String { self == .timestampToDate ? "时间戳 → 日期" : "日期 → 时间戳" }
}

enum TimestampUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case seconds
    case milliseconds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "自动识别"
        case .seconds: "秒"
        case .milliseconds: "毫秒"
        }
    }
}

enum JSONToolAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case format
    case minify
    case validate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .format: "格式化"
        case .minify: "压缩"
        case .validate: "仅校验"
        }
    }
}

enum HashAlgorithm: String, Codable, CaseIterable, Identifiable, Sendable {
    case md5
    case sha1
    case sha256
    case sha512

    var id: String { rawValue }

    var title: String {
        switch self {
        case .md5: "MD5"
        case .sha1: "SHA-1"
        case .sha256: "SHA-256"
        case .sha512: "SHA-512"
        }
    }

    var isLegacy: Bool { self == .md5 || self == .sha1 }
}

enum QRCorrectionLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "L（约 7%）"
        case .medium: "M（约 15%）"
        case .quartile: "Q（约 25%）"
        case .high: "H（约 30%）"
        }
    }
}

struct ToolboxPreferences: Codable, Hashable, Sendable {
    var favoriteToolIDs: Set<DeveloperToolID> = []
    var lastSelectedToolID: DeveloperToolID = .qrCode
    var restoreLastContent = false
    var globalShortcutEnabled = true
    var globalShortcut: GlobalShortcut = .controlOptionT

    var encodingFormat: EncodingFormat = .base64
    var encodingDirection: TransformDirection = .encode
    var timestampDirection: TimestampDirection = .timestampToDate
    var timestampUnit: TimestampUnit = .automatic
    var timestampTimeZoneIdentifier: String = TimeZone.current.identifier
    var jsonAction: JSONToolAction = .format
    var jsonIndentWidth = 2
    var qrCorrectionLevel: QRCorrectionLevel = .medium
    var qrOutputSize = 512
    var uuidCount = 1
    var uuidUppercase = false
    var hashAlgorithm: HashAlgorithm = .sha256
    var hashUppercase = false
}

extension ToolboxPreferences {
    private enum CodingKeys: String, CodingKey {
        case favoriteToolIDs, lastSelectedToolID, restoreLastContent
        case globalShortcutEnabled, globalShortcut
        case encodingFormat, encodingDirection
        case timestampDirection, timestampUnit, timestampTimeZoneIdentifier
        case jsonAction, jsonIndentWidth
        case qrCorrectionLevel, qrOutputSize
        case uuidCount, uuidUppercase
        case hashAlgorithm, hashUppercase
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        favoriteToolIDs = try values.decodeIfPresent(Set<DeveloperToolID>.self, forKey: .favoriteToolIDs) ?? []
        lastSelectedToolID = try values.decodeIfPresent(DeveloperToolID.self, forKey: .lastSelectedToolID) ?? .qrCode
        restoreLastContent = try values.decodeIfPresent(Bool.self, forKey: .restoreLastContent) ?? false
        globalShortcutEnabled = try values.decodeIfPresent(Bool.self, forKey: .globalShortcutEnabled) ?? true
        globalShortcut = try values.decodeIfPresent(GlobalShortcut.self, forKey: .globalShortcut) ?? .controlOptionT
        encodingFormat = try values.decodeIfPresent(EncodingFormat.self, forKey: .encodingFormat) ?? .base64
        encodingDirection = try values.decodeIfPresent(TransformDirection.self, forKey: .encodingDirection) ?? .encode
        timestampDirection = try values.decodeIfPresent(TimestampDirection.self, forKey: .timestampDirection) ?? .timestampToDate
        timestampUnit = try values.decodeIfPresent(TimestampUnit.self, forKey: .timestampUnit) ?? .automatic
        timestampTimeZoneIdentifier = try values.decodeIfPresent(String.self, forKey: .timestampTimeZoneIdentifier)
            ?? TimeZone.current.identifier
        jsonAction = try values.decodeIfPresent(JSONToolAction.self, forKey: .jsonAction) ?? .format
        jsonIndentWidth = try values.decodeIfPresent(Int.self, forKey: .jsonIndentWidth) ?? 2
        qrCorrectionLevel = try values.decodeIfPresent(QRCorrectionLevel.self, forKey: .qrCorrectionLevel) ?? .medium
        qrOutputSize = try values.decodeIfPresent(Int.self, forKey: .qrOutputSize) ?? 512
        uuidCount = try values.decodeIfPresent(Int.self, forKey: .uuidCount) ?? 1
        uuidUppercase = try values.decodeIfPresent(Bool.self, forKey: .uuidUppercase) ?? false
        hashAlgorithm = try values.decodeIfPresent(HashAlgorithm.self, forKey: .hashAlgorithm) ?? .sha256
        hashUppercase = try values.decodeIfPresent(Bool.self, forKey: .hashUppercase) ?? false
    }
}

struct ToolboxSessionSnapshot: Codable, Equatable, Sendable {
    var qrText = ""
    var encodingInput = ""
    var timestampInput = ""
    var timestampDate = Date()
    var jsonInput = ""
    var uuidResults: [String] = []
    var hashInput = ""
}
