import XCTest

final class DevSearchUITests: XCTestCase {
    private var app: XCUIApplication!
    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevSearchUITests-\(UUID().uuidString)", isDirectory: true)
        try createFixture(at: fixtureRoot)

        app = XCUIApplication()
        app.launchArguments = [
            "--show-search",
            "--scan-root", fixtureRoot.path,
            "--test-storage", fixtureRoot.appendingPathComponent("data.json").path,
            "--no-default-editor"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let fixtureRoot, fixtureRoot.path.contains("DevSearchUITests-") {
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
    }

    func testLaunchSearchAndNestedRepositoryPresentation() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 8))

        searchField.click()
        searchField.typeText("API")

        let api = projectButton(named: "API")
        XCTAssertTrue(api.waitForExistence(timeout: 3))
        XCTAssertTrue(api.label.contains("子仓库"))
        XCTAssertTrue(api.label.contains("services/API"))
    }

    func testCompactResultLayoutAndFilteredResultSummary() {
        let searchField = app.searchFields["search-field"]
        let modePicker = app.descendants(matching: .any)["quickPanelModePicker"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))

        XCTAssertLessThan(abs(searchField.frame.midY - modePicker.frame.midY), 8)
        XCTAssertGreaterThan(searchField.frame.width, modePicker.frame.width)

        let webApp = projectButton(named: "WebApp")
        XCTAssertTrue(webApp.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(webApp.frame.height, 62)

        searchField.typeText("API")

        let resultCount = app.descendants(matching: .any)["project-result-count"]
        XCTAssertTrue(resultCount.waitForExistence(timeout: 3))
        XCTAssertEqual(resultCount.label, "1 个结果")
        XCTAssertTrue(projectButton(named: "API").exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Compact project search results"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSearchFieldIsFocusedOnLaunch() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeText("API")

        XCTAssertEqual(searchField.value as? String, "API")
        XCTAssertTrue(projectButton(named: "API").waitForExistence(timeout: 3))
    }

    func testCoreControlsExposeAccessibleNames() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["quickPanelModePicker"].exists)

        let webApp = projectButton(named: "WebApp")
        XCTAssertTrue(webApp.waitForExistence(timeout: 3))
        XCTAssertTrue(webApp.label.contains("WebApp"))
        XCTAssertTrue(webApp.label.contains("/WebApp"))
        webApp.hover()

        XCTAssertTrue(app.buttons["收藏 WebApp"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["打开"].exists)
        XCTAssertTrue(app.menuButtons["其他方式"].exists)
    }

    func testHIGLayoutAndSettingsSearch() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 8))

        let panelScreenshot = XCTAttachment(screenshot: app.screenshot())
        panelScreenshot.name = "HIG project panel"
        panelScreenshot.lifetime = .keepAlways
        add(panelScreenshot)

        searchField.typeKey(",", modifierFlags: .command)
        let settingsSearch = app.searchFields["settings-search-field"]
        XCTAssertTrue(settingsSearch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Hide Sidebar"].exists)
        settingsSearch.click()
        settingsSearch.typeText("剪贴板")

        XCTAssertTrue(app.staticTexts["剪贴板"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["项目来源"].exists)
        XCTAssertFalse(app.staticTexts["打开方式"].exists)
        app.staticTexts["剪贴板"].click()
        XCTAssertTrue(app.staticTexts["记录文本剪贴板历史"].waitForExistence(timeout: 3))

        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot())
        settingsScreenshot.name = "HIG settings search"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)
    }

    func testSettingsWindowOpensFromStartupArgument() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "--show-settings",
            "--test-storage", fixtureRoot.appendingPathComponent("settings-data.json").path
        ]
        app.launch()

        let settingsSearch = app.searchFields["settings-search-field"]
        XCTAssertTrue(settingsSearch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.windows.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["通用"].exists)
    }

    func testNonContiguousFuzzySearch() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeText("wbp")

        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))
    }

    func testKeyboardSelectionShowsPreview() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("WebApp")
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))

        app.typeKey(.downArrow, modifierFlags: [])

        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
    }

    func testCommandRightEntersPreviewAndEscapeReturnsToSearch() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.typeText("WebApp")
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))

        searchField.typeKey(.rightArrow, modifierFlags: .command)

        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
        XCTAssertEqual(previewElement.value as? String, "交互预览")
        let openButton = app.buttons["打开"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 3))
        openButton.typeKey(.escape, modifierFlags: [])

        app.typeKey("A", modifierFlags: [])
        app.typeKey("P", modifierFlags: [])
        app.typeKey("I", modifierFlags: [])
        XCTAssertEqual(searchField.value as? String, "API")
    }

    func testHoverShowsPreview() {
        let projectName = projectButton(named: "EasyMoney")
        XCTAssertTrue(projectName.waitForExistence(timeout: 8))

        projectName.hover()

        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["EasyMoney"].exists)
    }

    func testHoveringIntoPreviewKeepsItVisible() {
        let projectName = projectButton(named: "EasyMoney")
        XCTAssertTrue(projectName.waitForExistence(timeout: 8))
        projectName.hover()
        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))

        let previewTitle = app.staticTexts["EasyMoney"]
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 3))
        previewTitle.hover()
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))

        XCTAssertTrue(previewElement.exists)
        XCTAssertTrue(previewTitle.exists)
    }

    func testExcludeProjectAndRestoreItFromSettings() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        let webApp = projectButton(named: "WebApp")
        XCTAssertTrue(webApp.waitForExistence(timeout: 8))
        webApp.rightClick()
        let exclude = app.menuItems["排除此项目"]
        XCTAssertTrue(exclude.waitForExistence(timeout: 3))
        exclude.click()

        XCTAssertTrue(app.staticTexts["从索引中排除项目？"].waitForExistence(timeout: 3))
        app.buttons["action-button-1"].click()
        XCTAssertFalse(webApp.waitForExistence(timeout: 2))
        XCTAssertTrue(projectButton(named: "API").waitForExistence(timeout: 3))

        searchField.typeKey(",", modifierFlags: .command)
        let projectSources = app.staticTexts["项目来源"]
        XCTAssertTrue(projectSources.waitForExistence(timeout: 3))
        projectSources.click()
        XCTAssertTrue(app.staticTexts["已排除项目"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["WebApp"].waitForExistence(timeout: 3))
        let restore = app.buttons["恢复"]
        XCTAssertTrue(restore.waitForExistence(timeout: 3))
        restore.click()

        XCTAssertTrue(app.staticTexts["没有排除规则"].waitForExistence(timeout: 3))
        XCTAssertTrue(webApp.waitForExistence(timeout: 3))
    }

    func testFirstLaunchShowsInlinePrivacyAndDirectoryGuidance() {
        app.terminate()
        app.launchArguments = [
            "--show-search",
            "--test-storage", fixtureRoot.appendingPathComponent("empty-data.json").path,
            "--no-default-editor"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["开始使用 RepoGlance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["选择扫描文件夹…"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["local-privacy-note"].exists)
    }

    func testOpeningWithoutDefaultEditorAsksForOpeningMethod() {
        let projectName = projectButton(named: "EasyMoney")
        XCTAssertTrue(projectName.waitForExistence(timeout: 8))

        projectName.click()

        XCTAssertTrue(app.staticTexts["选择打开方式"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["打开"].exists)
        XCTAssertTrue(app.buttons["取消"].exists)
    }

    func testCommandReturnOffersOpeningMethodFromNativeSearchField() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("EasyMoney")
        XCTAssertTrue(projectButton(named: "EasyMoney").waitForExistence(timeout: 3))

        searchField.typeKey(.return, modifierFlags: .command)

        XCTAssertTrue(app.staticTexts["选择打开方式"].waitForExistence(timeout: 3))
    }

    func testReturnOffersOpeningMethodForSelectedProject() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.typeText("EasyMoney")
        XCTAssertTrue(projectButton(named: "EasyMoney").waitForExistence(timeout: 3))

        searchField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["选择打开方式"].waitForExistence(timeout: 3))
    }

    func testContextMenuExposesTemporaryEditorChoices() {
        let project = projectButton(named: "EasyMoney")
        XCTAssertTrue(project.waitForExistence(timeout: 8))

        project.rightClick()
        let openingMethod = app.menuItems["打开方式"]
        XCTAssertTrue(openingMethod.waitForExistence(timeout: 3))
        openingMethod.hover()

        XCTAssertTrue(app.menuItems["Visual Studio Code"].waitForExistence(timeout: 3))
    }

    func testEscapeClearsQueryBeforeClosingPanel() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("API")
        XCTAssertEqual(searchField.value as? String, "API")

        searchField.typeKey(.escape, modifierFlags: [])

        XCTAssertEqual(searchField.value as? String, "")
        XCTAssertTrue(projectButton(named: "EasyMoney").waitForExistence(timeout: 3))
    }

    func testProjectMetadataSaveImmediatelyUpdatesSearchAndPreview() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.typeText("WebApp")
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))
        searchField.typeKey(.downArrow, modifierFlags: [])
        searchField.typeKey(.upArrow, modifierFlags: [])
        searchField.typeKey("k", modifierFlags: .command)

        let editorWindow = app.windows["编辑项目信息"]
        XCTAssertTrue(editorWindow.waitForExistence(timeout: 3))
        let editorScreenshot = XCTAttachment(screenshot: editorWindow.screenshot())
        editorScreenshot.name = "Project editor native layout"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)
        let displayName = editorWindow.textFields["project-display-name"]
        displayName.click()
        displayName.typeKey("a", modifierFlags: .command)
        displayName.typeText("工作台")
        let tags = editorWindow.textFields["project-tags"]
        tags.click()
        tags.typeText("macOS, 工具")
        let description = editorWindow.textViews["project-description"]
        description.click()
        description.typeText("## 本地项目\n用于验收即时更新。")
        editorWindow.buttons["project-save"].click()

        let updated = projectButton(named: "工作台")
        XCTAssertTrue(updated.waitForExistence(timeout: 3))
        XCTAssertTrue(updated.label.contains("标签 macOS，工具"))
        searchField.click()
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("本地项目")
        let descriptionResult = projectButton(named: "工作台")
        XCTAssertTrue(descriptionResult.waitForExistence(timeout: 3))
        descriptionResult.hover()
        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
        let previewTitle = app.staticTexts["工作台"]
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 3))
    }

    func testDirtyProjectEditorPromptsBeforeWindowClose() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.typeText("WebApp")
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))
        searchField.typeKey("k", modifierFlags: .command)

        let editorWindow = app.windows["编辑项目信息"]
        XCTAssertTrue(editorWindow.waitForExistence(timeout: 3))
        let displayName = editorWindow.textFields["project-display-name"]
        displayName.click()
        displayName.typeText("未保存")
        editorWindow.buttons[XCUIIdentifierCloseWindow].click()

        XCTAssertTrue(app.staticTexts["放弃未保存的更改？"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["继续编辑"].exists)
        XCTAssertTrue(app.buttons["放弃更改"].exists)
    }

    func testClipboardModeRecordsSearchesAndCopiesWithKeyboard() {
        let searchField = app.searchFields["search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeKey("2", modifierFlags: .command)
        let enable = app.buttons["启用剪贴板记录"]
        XCTAssertTrue(enable.waitForExistence(timeout: 3))
        enable.click()

        searchField.click()
        searchField.typeText("RepoGlance clipboard keyboard flow")
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey("c", modifierFlags: .command)

        let captured = app.staticTexts["RepoGlance clipboard keyboard flow"]
        XCTAssertTrue(captured.waitForExistence(timeout: 3))

        searchField.typeKey(.return, modifierFlags: [])
        XCTAssertFalse(app.windows.firstMatch.waitForExistence(timeout: 1))
    }

    private func createFixture(at root: URL) throws {
        let fileManager = FileManager.default
        let web = root.appendingPathComponent("WebApp", isDirectory: true)
        let api = web.appendingPathComponent("services/API", isDirectory: true)
        let easyMoney = root.appendingPathComponent("EasyMoney", isDirectory: true)

        for repository in [web, api, easyMoney] {
            try fileManager.createDirectory(
                at: repository.appendingPathComponent(".git", isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        try Data("# WebApp\nNative project search fixture.".utf8)
            .write(to: web.appendingPathComponent("README.md"))
        try Data("# API\nNested service fixture.".utf8)
            .write(to: api.appendingPathComponent("README.md"))
    }

    private func projectButton(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name)，")).firstMatch
    }

    private var previewElement: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "project-preview")
            .firstMatch
    }
}
