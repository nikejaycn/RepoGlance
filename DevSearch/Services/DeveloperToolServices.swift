import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import Foundation

enum DeveloperToolError: LocalizedError, Equatable {
    case emptyInput
    case invalidBase64
    case invalidPercentEncoding
    case invalidHex
    case invalidUTF8
    case invalidTimestamp
    case timestampOutOfRange
    case invalidJSON(message: String, line: Int?, column: Int?)
    case qrContentTooLarge
    case qrGenerationFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput: "请输入要处理的内容。"
        case .invalidBase64: "输入不是有效的 Base64。"
        case .invalidPercentEncoding: "输入包含不完整或无效的百分号编码。"
        case .invalidHex: "Hex 必须由成对的十六进制字符组成。"
        case .invalidUTF8: "解码后的字节不是有效的 UTF-8 文本。"
        case .invalidTimestamp: "请输入有效的数字时间戳。"
        case .timestampOutOfRange: "时间戳超出可表示范围（公元 1 年至 9999 年）。"
        case let .invalidJSON(message, line, column):
            if let line, let column { "第 \(line) 行、第 \(column) 列：\(message)" }
            else { message }
        case .qrContentTooLarge: "内容超过当前纠错等级可生成的二维码容量。"
        case .qrGenerationFailed: "无法生成二维码，请调整内容后重试。"
        }
    }
}

enum EncodingService {
    static func transform(
        _ input: String,
        format: EncodingFormat,
        direction: TransformDirection
    ) throws -> String {
        switch (format, direction) {
        case (.base64, .encode):
            return Data(input.utf8).base64EncodedString()
        case (.base64, .decode):
            let compact = input.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: compact) else { throw DeveloperToolError.invalidBase64 }
            guard let result = String(data: data, encoding: .utf8) else { throw DeveloperToolError.invalidUTF8 }
            return result
        case (.urlPercent, .encode):
            return percentEncode(input)
        case (.urlPercent, .decode):
            guard hasValidPercentEscapes(input), let result = input.removingPercentEncoding else {
                throw DeveloperToolError.invalidPercentEncoding
            }
            return result
        case (.htmlEntity, .encode):
            return htmlEncode(input)
        case (.htmlEntity, .decode):
            return htmlDecode(input)
        case (.utf8Hex, .encode):
            return Data(input.utf8).map { String(format: "%02x", $0) }.joined(separator: " ")
        case (.utf8Hex, .decode):
            let compact = input.filter { !$0.isWhitespace }
            guard compact.count.isMultiple(of: 2), compact.allSatisfy(\.isHexDigit) else {
                throw DeveloperToolError.invalidHex
            }
            var data = Data(capacity: compact.count / 2)
            var index = compact.startIndex
            while index < compact.endIndex {
                let next = compact.index(index, offsetBy: 2)
                guard let byte = UInt8(compact[index..<next], radix: 16) else {
                    throw DeveloperToolError.invalidHex
                }
                data.append(byte)
                index = next
            }
            guard let result = String(data: data, encoding: .utf8) else { throw DeveloperToolError.invalidUTF8 }
            return result
        }
    }

    private static func percentEncode(_ input: String) -> String {
        let unreserved = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~".utf8)
        return input.utf8.map { byte in
            unreserved.contains(byte) ? String(UnicodeScalar(byte)) : String(format: "%%%02X", byte)
        }.joined()
    }

    private static func hasValidPercentEscapes(_ input: String) -> Bool {
        let characters = Array(input)
        var index = 0
        while index < characters.count {
            if characters[index] == "%" {
                guard index + 2 < characters.count,
                      characters[index + 1].isHexDigit,
                      characters[index + 2].isHexDigit
                else { return false }
                index += 3
            } else {
                index += 1
            }
        }
        return true
    }

    private static func htmlEncode(_ input: String) -> String {
        input.reduce(into: "") { result, character in
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
    }

    private static func htmlDecode(_ input: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: "&(#x[0-9A-Fa-f]+|#[0-9]+|amp|lt|gt|quot|apos);"
        ) else { return input }
        var result = input
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        for match in expression.matches(in: input, range: range).reversed() {
            guard let wholeRange = Range(match.range(at: 0), in: result),
                  let entityRange = Range(match.range(at: 1), in: input)
            else { continue }
            let entity = String(input[entityRange])
            let replacement: String? = switch entity {
            case "amp": "&"
            case "lt": "<"
            case "gt": ">"
            case "quot": "\""
            case "apos": "'"
            default: numericEntity(entity)
            }
            if let replacement { result.replaceSubrange(wholeRange, with: replacement) }
        }
        return result
    }

    private static func numericEntity(_ entity: String) -> String? {
        let value: UInt32?
        if entity.hasPrefix("#x") { value = UInt32(entity.dropFirst(2), radix: 16) }
        else if entity.hasPrefix("#") { value = UInt32(entity.dropFirst(), radix: 10) }
        else { value = nil }
        guard let value, let scalar = UnicodeScalar(value) else { return nil }
        return String(Character(scalar))
    }
}

struct TimestampConversion: Equatable, Sendable {
    let date: Date
    let detectedUnit: TimestampUnit
    let seconds: String
    let milliseconds: String
    let iso8601: String
    let readable: String
}

enum TimestampService {
    private static let minimumSeconds = -62_135_596_800.0
    private static let maximumSeconds = 253_402_300_799.999

    static func convert(
        timestamp input: String,
        unit: TimestampUnit,
        timeZone: TimeZone
    ) throws -> TimestampConversion {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Double(trimmed), raw.isFinite else { throw DeveloperToolError.invalidTimestamp }
        let detected: TimestampUnit = if unit == .automatic {
            abs(raw) >= 100_000_000_000 ? .milliseconds : .seconds
        } else {
            unit
        }
        let seconds = detected == .milliseconds ? raw / 1_000 : raw
        guard seconds >= minimumSeconds, seconds <= maximumSeconds else {
            throw DeveloperToolError.timestampOutOfRange
        }
        return conversion(for: Date(timeIntervalSince1970: seconds), detectedUnit: detected, timeZone: timeZone)
    }

    static func convert(date: Date, timeZone: TimeZone) -> TimestampConversion {
        conversion(for: date, detectedUnit: .seconds, timeZone: timeZone)
    }

    private static func conversion(
        for date: Date,
        detectedUnit: TimestampUnit,
        timeZone: TimeZone
    ) -> TimestampConversion {
        let secondsValue = date.timeIntervalSince1970
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = timeZone

        let readable = DateFormatter()
        readable.locale = Locale.current
        readable.timeZone = timeZone
        readable.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS zzz"

        return TimestampConversion(
            date: date,
            detectedUnit: detectedUnit,
            seconds: decimalString(secondsValue, maximumFractionDigits: 6),
            milliseconds: decimalString(secondsValue * 1_000, maximumFractionDigits: 3),
            iso8601: iso.string(from: date),
            readable: readable.string(from: date)
        )
    }

    private static func decimalString(_ value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum JSONService {
    static func process(_ input: String, action: JSONToolAction, indentWidth: Int = 2) throws -> String {
        let data = Data(input.utf8)
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw parseJSONError(error)
        }
        switch action {
        case .validate: return "JSON 有效"
        case .minify: return transformWhitespace(input, indentWidth: 0)
        case .format: return transformWhitespace(input, indentWidth: max(1, indentWidth))
        }
    }

    private static func transformWhitespace(_ input: String, indentWidth: Int) -> String {
        let characters = Array(input)
        var output = ""
        var level = 0
        var inString = false
        var escaped = false

        func appendIndent(_ level: Int, to output: inout String) {
            output += String(repeating: " ", count: max(0, level * indentWidth))
        }

        for (index, character) in characters.enumerated() {
            if inString {
                output.append(character)
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
                continue
            }

            if character == "\"" {
                inString = true
                output.append(character)
                continue
            }
            if character.isWhitespace { continue }

            if indentWidth == 0 {
                output.append(character)
                continue
            }

            switch character {
            case "{", "[":
                output.append(character)
                let closing: Character = character == "{" ? "}" : "]"
                let next = characters.dropFirst(index + 1).first { !$0.isWhitespace }
                if next != closing {
                    level += 1
                    output.append("\n")
                    appendIndent(level, to: &output)
                }
            case "}", "]":
                let opening: Character = character == "}" ? "{" : "["
                let previous = characters[..<index].reversed().first { !$0.isWhitespace }
                if previous != opening {
                    level = max(0, level - 1)
                    output.append("\n")
                    appendIndent(level, to: &output)
                }
                output.append(character)
            case ",":
                output.append(",\n")
                appendIndent(level, to: &output)
            case ":": output.append(": ")
            default: output.append(character)
            }
        }
        return output
    }

    private static func parseJSONError(_ error: Error) -> DeveloperToolError {
        let nsError = error as NSError
        let rawMessage = (nsError.userInfo["NSDebugDescription"] as? String) ?? nsError.localizedDescription
        let pattern = #"around line ([0-9]+), column ([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: rawMessage, range: NSRange(rawMessage.startIndex..., in: rawMessage)),
              let lineRange = Range(match.range(at: 1), in: rawMessage),
              let columnRange = Range(match.range(at: 2), in: rawMessage)
        else { return .invalidJSON(message: rawMessage, line: nil, column: nil) }
        return .invalidJSON(
            message: rawMessage.replacingOccurrences(of: #" around line [0-9]+, column [0-9]+.*"#, with: "", options: .regularExpression),
            line: Int(rawMessage[lineRange]),
            column: Int(rawMessage[columnRange])
        )
    }
}

enum UUIDService {
    static func generate(
        count: Int,
        uppercase: Bool,
        generator: () -> UUID = UUID.init
    ) -> [String] {
        (0..<max(1, min(20, count))).map { _ in
            let value = generator().uuidString
            return uppercase ? value.uppercased() : value.lowercased()
        }
    }
}

enum HashService {
    static func digest(_ input: String, algorithm: HashAlgorithm, uppercase: Bool = false) -> String {
        let data = Data(input.utf8)
        let bytes: [UInt8] = switch algorithm {
        case .md5: Array(Insecure.MD5.hash(data: data))
        case .sha1: Array(Insecure.SHA1.hash(data: data))
        case .sha256: Array(SHA256.hash(data: data))
        case .sha512: Array(SHA512.hash(data: data))
        }
        let output = bytes.map { String(format: "%02x", $0) }.joined()
        return uppercase ? output.uppercased() : output
    }
}

enum QRCodeService {
    static func generate(
        text: String,
        correctionLevel: QRCorrectionLevel,
        size: Int
    ) throws -> CGImage {
        let output = try matrix(text: text, correctionLevel: correctionLevel)

        let context = CIContext(options: [
            .cacheIntermediates: false,
            .useSoftwareRenderer: true
        ])
        let renderColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let source = context.createCGImage(
            output,
            from: output.extent,
            format: .RGBA8,
            colorSpace: renderColorSpace
        ) else {
            throw DeveloperToolError.qrGenerationFailed
        }

        return try render(source: source, size: size)
    }

    static func matrix(text: String, correctionLevel: QRCorrectionLevel) throws -> CIImage {
        guard !text.isEmpty else { throw DeveloperToolError.emptyInput }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = correctionLevel.rawValue
        guard let output = filter.outputImage else { throw DeveloperToolError.qrContentTooLarge }
        return output
    }

    private static func render(source: CGImage, size: Int) throws -> CGImage {
        let targetSize = max(128, size)
        let quietZoneModules = 4
        let moduleCount = source.width
        let scale = targetSize / (moduleCount + quietZoneModules * 2)
        guard scale >= 1 else { throw DeveloperToolError.qrContentTooLarge }
        let codeSize = moduleCount * scale
        let offset = (targetSize - codeSize) / 2

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let canvas = CGContext(
                data: nil,
                width: targetSize,
                height: targetSize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { throw DeveloperToolError.qrGenerationFailed }

        canvas.setFillColor(NSColor.white.cgColor)
        canvas.fill(CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
        canvas.interpolationQuality = .none
        canvas.setAllowsAntialiasing(false)
        canvas.draw(source, in: CGRect(x: offset, y: offset, width: codeSize, height: codeSize))
        guard let image = canvas.makeImage() else { throw DeveloperToolError.qrGenerationFailed }
        return image
    }

    static func pngData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
