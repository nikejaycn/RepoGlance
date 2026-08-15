import XCTest
@testable import DevSearch

final class DeveloperToolServicesTests: XCTestCase {
    func testBase64RoundTripPreservesUnicodeAndNewlines() throws {
        let input = "你好 👋\nRepoGlance"
        let encoded = try EncodingService.transform(input, format: .base64, direction: .encode)
        let decoded = try EncodingService.transform(encoded, format: .base64, direction: .decode)
        XCTAssertEqual(decoded, input)
    }

    func testBase64RejectsInvalidCharacters() {
        XCTAssertThrowsError(
            try EncodingService.transform("not!base64", format: .base64, direction: .decode)
        ) { XCTAssertEqual($0 as? DeveloperToolError, .invalidBase64) }
    }

    func testURLPercentEncodingUsesRFC3986AndDoesNotTreatPlusAsSpace() throws {
        let encoded = try EncodingService.transform("a+b 中文", format: .urlPercent, direction: .encode)
        XCTAssertEqual(encoded, "a%2Bb%20%E4%B8%AD%E6%96%87")
        XCTAssertEqual(
            try EncodingService.transform(encoded, format: .urlPercent, direction: .decode),
            "a+b 中文"
        )
        XCTAssertEqual(
            try EncodingService.transform("a+b", format: .urlPercent, direction: .decode),
            "a+b"
        )
    }

    func testURLPercentDecodeRejectsIncompleteEscape() {
        XCTAssertThrowsError(
            try EncodingService.transform("abc%2", format: .urlPercent, direction: .decode)
        ) { XCTAssertEqual($0 as? DeveloperToolError, .invalidPercentEncoding) }
    }

    func testHTMLEntityDecodeIsSinglePassAndSupportsNumericEntities() throws {
        XCTAssertEqual(
            try EncodingService.transform("&amp;lt; &#x1F44B;", format: .htmlEntity, direction: .decode),
            "&lt; 👋"
        )
    }

    func testUTF8HexRoundTrip() throws {
        let encoded = try EncodingService.transform("A中", format: .utf8Hex, direction: .encode)
        XCTAssertEqual(encoded, "41 e4 b8 ad")
        XCTAssertEqual(
            try EncodingService.transform(encoded, format: .utf8Hex, direction: .decode),
            "A中"
        )
    }

    func testTimestampAutoDetectsSecondsAndMilliseconds() throws {
        let zone = TimeZone(secondsFromGMT: 0)!
        let seconds = try TimestampService.convert(timestamp: "1723723200", unit: .automatic, timeZone: zone)
        let milliseconds = try TimestampService.convert(timestamp: "1723723200000", unit: .automatic, timeZone: zone)
        XCTAssertEqual(seconds.date, milliseconds.date)
        XCTAssertEqual(seconds.detectedUnit, .seconds)
        XCTAssertEqual(milliseconds.detectedUnit, .milliseconds)
        XCTAssertTrue(seconds.iso8601.hasPrefix("2024-08-15T"))
    }

    func testTimestampRejectsOutOfRangeValue() {
        XCTAssertThrowsError(
            try TimestampService.convert(
                timestamp: "99999999999999999999",
                unit: .seconds,
                timeZone: .gmt
            )
        ) { XCTAssertEqual($0 as? DeveloperToolError, .timestampOutOfRange) }
    }

    func testJSONFormatAndMinifyPreserveKeyOrder() throws {
        let input = #"{"z":1,"a":[true,{"b":"x y"}]}"#
        let formatted = try JSONService.process(input, action: .format, indentWidth: 2)
        XCTAssertTrue(formatted.hasPrefix("{\n  \"z\": 1,\n  \"a\""))
        XCTAssertEqual(try JSONService.process(formatted, action: .minify), input)
        XCTAssertEqual(try JSONService.process(input, action: .validate), "JSON 有效")
    }

    func testInvalidJSONReturnsStructuredError() {
        XCTAssertThrowsError(try JSONService.process(#"{"a":}"#, action: .format)) { error in
            guard case .invalidJSON = error as? DeveloperToolError else {
                return XCTFail("Expected invalidJSON, got \(error)")
            }
        }
    }

    func testUUIDGenerationHonorsCountAndCasing() {
        let fixed = UUID(uuidString: "123E4567-E89B-42D3-A456-426614174000")!
        let values = UUIDService.generate(count: 5, uppercase: false) { fixed }
        XCTAssertEqual(values.count, 5)
        XCTAssertEqual(values.first, "123e4567-e89b-42d3-a456-426614174000")
    }

    func testHashStandardVectors() {
        XCTAssertEqual(HashService.digest("abc", algorithm: .md5), "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(HashService.digest("abc", algorithm: .sha1), "a9993e364706816aba3e25717850c26c9cd0d89d")
        XCTAssertEqual(
            HashService.digest("abc", algorithm: .sha256),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testQRCodeHasRequestedPixelSizeAndPNGRepresentation() throws {
        let text = "https://example.com"
        let matrix = try QRCodeService.matrix(text: text, correctionLevel: .medium)
        XCTAssertGreaterThan(matrix.extent.width, 0)
        let image: CGImage
        do {
            image = try QRCodeService.generate(text: text, correctionLevel: .medium, size: 512)
        } catch DeveloperToolError.qrGenerationFailed {
            throw XCTSkip("Core Image bitmap rendering is unavailable in this headless test process.")
        }
        XCTAssertEqual(image.width, 512)
        XCTAssertEqual(image.height, 512)
        XCTAssertFalse(try XCTUnwrap(QRCodeService.pngData(from: image)).isEmpty)
    }
}
