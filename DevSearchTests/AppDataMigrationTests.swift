import XCTest
@testable import DevSearch

final class AppDataMigrationTests: XCTestCase {
    func testOlderDataWithoutNewPreferenceAndIndexFieldsLoadsWithDefaults() throws {
        let json = #"""
        {
          "scanRoots": [{"canonicalPath":"/tmp/dev"}],
          "projects": [{"canonicalPath":"/tmp/dev/sample"}],
          "preferences": {}
        }
        """#

        let data = try JSONDecoder().decode(AppData.self, from: Data(json.utf8))

        XCTAssertEqual(data.scanRoots.first?.maximumDepth, 64)
        XCTAssertEqual(data.scanRoots.first?.scanHiddenDirectories, false)
        XCTAssertEqual(data.scanRoots.first?.ignoredRelativePaths, [])
        XCTAssertEqual(data.projects.first?.directoryName, "sample")
        XCTAssertEqual(data.projects.first?.customDescription, "")
        XCTAssertEqual(data.preferences.previewDelayMilliseconds, 400)
        XCTAssertEqual(data.preferences.automaticScanIntervalMinutes, 15)
        XCTAssertTrue(data.preferences.globalShortcutEnabled)
        XCTAssertEqual(data.preferences.globalShortcut, .optionSpace)
    }
}
