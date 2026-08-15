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
        XCTAssertFalse(data.preferences.clipboardHistoryEnabled)
        XCTAssertEqual(data.preferences.clipboardHistoryLimit, 100)
        XCTAssertTrue(data.clipboardItems.isEmpty)
        XCTAssertEqual(data.toolboxPreferences.lastSelectedToolID, .qrCode)
        XCTAssertFalse(data.toolboxPreferences.restoreLastContent)
        XCTAssertTrue(data.toolboxPreferences.globalShortcutEnabled)
        XCTAssertEqual(data.toolboxPreferences.globalShortcut, .controlOptionT)
    }

    func testDuplicateLegacyRecordsKeepLastValueInsteadOfCrashingAtStartup() throws {
        let json = #"""
        {
          "scanRoots": [
            {"canonicalPath":"/tmp/dev","displayPath":"old"},
            {"canonicalPath":"/tmp/dev","displayPath":"new"}
          ],
          "projects": [
            {"canonicalPath":"/tmp/dev/sample","customDescription":"old"},
            {"canonicalPath":"/tmp/dev/sample","customDescription":"new"}
          ],
          "editors": [
            {
              "id":"com.example.Editor",
              "name":"Old Editor",
              "bundleIdentifier":"com.example.Editor",
              "isManuallyAdded":true
            },
            {
              "id":"com.example.Editor",
              "name":"New Editor",
              "bundleIdentifier":"com.example.Editor",
              "isManuallyAdded":true
            }
          ]
        }
        """#

        let data = try JSONDecoder().decode(AppData.self, from: Data(json.utf8))

        XCTAssertEqual(data.scanRoots.count, 1)
        XCTAssertEqual(data.scanRoots.first?.displayPath, "new")
        XCTAssertEqual(data.projects.count, 1)
        XCTAssertEqual(data.projects.first?.customDescription, "new")
        XCTAssertEqual(data.editors.count, 1)
        XCTAssertEqual(data.editors.first?.name, "New Editor")
    }
}
