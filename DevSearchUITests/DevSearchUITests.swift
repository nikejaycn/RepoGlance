import XCTest
import AppKit

@MainActor
final class DevSearchUITests: XCTestCase {
    private var app: XCUIApplication!
    private var fixtureRoot: URL!

    override func setUp() async throws {
        try await MainActor.run {
            continueAfterFailure = false
            fixtureRoot = URL(fileURLWithPath: "/private/tmp/RepoGlance-UITest-Fixtures", isDirectory: true)
                .appendingPathComponent("DevSearchUITests-\(UUID().uuidString)", isDirectory: true)
            try createFixture(at: fixtureRoot)

            app = XCUIApplication()
            app.launchArguments = [
                "--show-search",
                "--scan-root", fixtureRoot.path,
                "--test-storage", testStorage("data.json"),
                "--no-default-editor"
            ]
            app.launch()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            app?.terminate()
            if let fixtureRoot, fixtureRoot.path.contains("DevSearchUITests-") {
                try? FileManager.default.removeItem(at: fixtureRoot)
            }
        }
    }

    func testLaunchSearchAndNestedRepositoryPresentation() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        let searchField = app.searchFields["search-field"].firstMatch
        let modePicker = app.descendants(matching: .any)["quickPanelModePicker"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(modePicker.waitForExistence(timeout: 3))

        XCTAssertLessThan(abs(searchField.frame.midY - modePicker.frame.midY), 8)
        XCTAssertGreaterThan(searchField.frame.width, modePicker.frame.width)

        let webApp = projectButton(named: "WebApp")
        XCTAssertTrue(webApp.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(webApp.frame.height, 62)

        searchField.typeText("services/API")

        let resultCount = app.staticTexts["project-result-count"].firstMatch
        XCTAssertTrue(resultCount.waitForExistence(timeout: 3))
        let countReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ OR value == %@", "1 个结果", "1 个结果"),
            object: resultCount
        )
        XCTAssertEqual(XCTWaiter.wait(for: [countReady], timeout: 3), .completed)
        XCTAssertTrue(projectButton(named: "API").exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Compact project search results"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSearchFieldIsFocusedOnLaunch() {
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeText("API")

        XCTAssertEqual(searchField.value as? String, "API")
        XCTAssertTrue(projectButton(named: "API").waitForExistence(timeout: 3))
    }

    func testCoreControlsExposeAccessibleNames() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 8))

        let panelScreenshot = XCTAttachment(screenshot: app.screenshot())
        panelScreenshot.name = "HIG project panel"
        panelScreenshot.lifetime = .keepAlways
        add(panelScreenshot)

        searchField.typeKey(",", modifierFlags: .command)
        let settingsSearch = app.searchFields["settings-search-field"].firstMatch
        XCTAssertTrue(settingsSearch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Hide Sidebar"].exists)
        settingsSearch.click()
        settingsSearch.typeText("剪贴板")

        let results = app.outlines["settings-sidebar"].staticTexts
        let filtered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 1"), object: results)
        XCTAssertEqual(XCTWaiter.wait(for: [filtered], timeout: 3), .completed)
        XCTAssertTrue(results["剪贴板"].firstMatch.exists)
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
            "--test-storage", testStorage("settings-data.json")
        ]
        app.launch()

        let settingsSearch = app.searchFields["settings-search-field"].firstMatch
        XCTAssertTrue(settingsSearch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.windows.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["通用"].exists)
    }

    func testNonContiguousFuzzySearch() {
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeText("wbp")

        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))
    }

    func testKeyboardSelectionShowsPreview() {
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("WebApp")
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))

        app.typeKey(.downArrow, modifierFlags: [])

        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
    }

    func testCommandRightEntersPreviewAndEscapeReturnsToSearch() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        let searchField = app.searchFields["search-field"].firstMatch
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
        app.activate()
        app.menuBars.menuBarItems.matching(NSPredicate(format: "title IN %@", ["File", "文件"])).firstMatch.click()
        app.menuItems["搜索项目"].click()
        XCTAssertTrue(projectButton(named: "WebApp").waitForExistence(timeout: 3))
    }

    func testFirstLaunchShowsInlinePrivacyAndDirectoryGuidance() {
        app.terminate()
        app.launchArguments = [
            "--show-search",
            "--test-storage", testStorage("empty-data.json"),
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
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("EasyMoney")
        XCTAssertTrue(projectButton(named: "EasyMoney").waitForExistence(timeout: 3))

        searchField.typeKey(.return, modifierFlags: .command)

        XCTAssertTrue(app.staticTexts["选择打开方式"].waitForExistence(timeout: 3))
    }

    func testReturnOffersOpeningMethodForSelectedProject() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("API")
        XCTAssertEqual(searchField.value as? String, "API")

        searchField.typeKey(.escape, modifierFlags: [])

        XCTAssertEqual(searchField.value as? String, "")
        XCTAssertTrue(projectButton(named: "EasyMoney").waitForExistence(timeout: 3))
    }

    func testProjectMetadataSaveImmediatelyUpdatesSearchAndPreview() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        searchField.typeKey(.rightArrow, modifierFlags: .command)
        XCTAssertTrue(previewElement.waitForExistence(timeout: 3))
        let previewTitle = app.staticTexts["工作台"]
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 3))
    }

    func testDirtyProjectEditorPromptsBeforeWindowClose() {
        let searchField = app.searchFields["search-field"].firstMatch
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
        let searchField = app.searchFields["search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))

        searchField.typeKey("2", modifierFlags: .command)
        let enable = app.buttons["启用剪贴板记录"]
        XCTAssertTrue(enable.waitForExistence(timeout: 3))
        enable.click()

        searchField.click()
        searchField.typeText("RepoGlance clipboard keyboard flow")
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey("c", modifierFlags: .command)

        let captured = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "RepoGlance clipboard keyboard flow")).firstMatch
        XCTAssertTrue(captured.waitForExistence(timeout: 3))

        searchField.typeKey(.return, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 1))
    }

    func testToolboxShowsAllToolsAndTransformsText() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "--show-toolbox",
            "--test-storage", testStorage("toolbox-data.json"),
            "--toolbox-storage", testStorage("toolbox-session.json")
        ]
        app.launch()

        let searchField = app.searchFields["toolbox-search-field"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        for title in ["二维码生成", "编码转换", "时间戳换算", "JSON 工具", "UUID 生成", "哈希摘要"] {
            XCTAssertTrue(app.staticTexts[title].exists, "Missing toolbox item: \(title)")
        }

        app.staticTexts["编码转换"].click()
        XCTAssertFalse(app.staticTexts["最近使用"].exists)
        let input = app.textViews["toolbox-primary-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText("RepoGlance")

        let output = app.descendants(matching: .any)["toolbox-output"]
        XCTAssertTrue(output.waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value == %@", "UmVwb0dsYW5jZQ==")).firstMatch.waitForExistence(timeout: 3))

        searchField.click()
        searchField.typeText("hash")
        XCTAssertTrue(app.staticTexts["哈希摘要"].waitForExistence(timeout: 3))
        searchField.typeKey(.downArrow, modifierFlags: [])
        searchField.typeKey(.return, modifierFlags: [])
        input.typeText("abc")
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value == %@", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")).firstMatch.waitForExistence(timeout: 3))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Developer toolbox"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testToolboxAndSettingsAppearanceCoverage() {
        for appearance in ["Light", "Dark"] {
            app.terminate()
            app.launchArguments = [
                "--show-toolbox", "--test-storage", testStorage("appearance-data.json"),
                "--toolbox-storage", testStorage("appearance-tools.json"),
                "--appearance", appearance
            ]
            app.launch()
            let search = app.searchFields["toolbox-search-field"].firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 8))
            let sidebar = app.descendants(matching: .any)["toolbox-sidebar"].firstMatch
            for title in ["二维码生成", "编码转换", "时间戳换算", "JSON 工具", "UUID 生成", "哈希摘要"] {
                sidebar.staticTexts[title].firstMatch.click()
                XCTAssertTrue(app.windows.firstMatch.exists)
                attachWindow("\(appearance) — \(title)")
            }
            search.click()
            search.typeText("no-such-tool")
            XCTAssertTrue(app.buttons["清除搜索"].waitForExistence(timeout: 3))
            attachWindow("\(appearance) — 空搜索")
            app.buttons["清除搜索"].click()
            app.typeKey(",", modifierFlags: .command)
            let settingsSearch = app.searchFields["settings-search-field"].firstMatch
            XCTAssertTrue(settingsSearch.waitForExistence(timeout: 5))
            let settingsSidebar = app.descendants(matching: .any)["settings-sidebar"].firstMatch
            for title in ["通用", "项目来源", "打开方式", "剪贴板", "开发工具箱", "数据与关于"] {
                settingsSidebar.staticTexts[title].firstMatch.click()
                attachWindow("\(appearance) — 设置 — \(title)")
            }
            settingsSidebar.staticTexts["项目来源"].firstMatch.click()
            app.buttons["添加目录…"].click()
            XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
            attachWindow("\(appearance) — 添加目录表单")
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: 1))
        }
    }

    func testCompactToolboxPreservesControlsAndClearCanBeCancelled() {
        app.terminate()
        app.launchArguments = ["--show-toolbox", "--compact-toolbox", "--test-storage", testStorage("compact.json"),
                               "--toolbox-storage", testStorage("compact-tools.json")]
        app.launch()
        XCTAssertTrue(app.searchFields["toolbox-search-field"].firstMatch.waitForExistence(timeout: 8))
        let window = app.windows.firstMatch
        XCTAssertLessThanOrEqual(window.frame.width, 800)
        let sidebar = app.outlines["toolbox-sidebar"].firstMatch
        for title in ["二维码生成", "编码转换", "时间戳换算", "JSON 工具", "UUID 生成", "哈希摘要"] {
            sidebar.staticTexts[title].firstMatch.click()
            attachWindow("Compact — \(title)")
        }
        let input = app.textViews["toolbox-primary-input"].firstMatch
        input.click()
        input.typeText("keep this text")
        app.toolbars.buttons["清空内容"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        attachWindow("清空确认表单")
        app.sheets.firstMatch.buttons["取消"].firstMatch.click()
        XCTAssertEqual(input.value as? String, "keep this text")
    }

    func testToolboxGenerationValidationAndExportCancellation() {
        app.terminate()
        app.launchArguments = ["--show-toolbox", "--test-storage", testStorage("generation.json"),
                               "--toolbox-storage", testStorage("generation-tools.json")]
        app.launch()
        XCTAssertTrue(app.searchFields["toolbox-search-field"].firstMatch.waitForExistence(timeout: 8))
        let sidebar = app.outlines["toolbox-sidebar"].firstMatch
        sidebar.staticTexts["二维码生成"].firstMatch.click()
        let input = app.textViews["toolbox-primary-input"].firstMatch
        input.click()
        input.typeText("RepoGlance")
        let export = app.buttons["导出 PNG…"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: export)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
        attachWindow("生成二维码")
        export.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: 1))
        XCTAssertEqual(input.value as? String, "RepoGlance")

        sidebar.staticTexts["JSON 工具"].firstMatch.click()
        input.click()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("{bad}", forType: .string)
        input.typeKey("v", modifierFlags: .command)
        let error = app.descendants(matching: .any)["toolbox-error"].firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        attachWindow("JSON 错误状态")
        // Paste literal code so the active Chinese input method doesn't transform punctuation.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("{\"ok\":true}", forType: .string)
        input.click()
        input.typeKey("a", modifierFlags: .command)
        input.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value CONTAINS %@", "\"ok\": true")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(error.exists)

        sidebar.staticTexts["时间戳换算"].firstMatch.click()
        let timestamp = app.textFields["toolbox-primary-input"].firstMatch
        timestamp.click()
        timestamp.typeText("0")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "1970-01-01")).firstMatch.waitForExistence(timeout: 3))
        attachWindow("时间戳结果")

        sidebar.staticTexts["UUID 生成"].firstMatch.click()
        let output = app.textViews["UUID v4"].firstMatch
        XCTAssertTrue(output.waitForExistence(timeout: 3))
        let first = output.value as? String
        XCTAssertNotNil(first.flatMap(UUID.init(uuidString:)))
        app.buttons["重新生成"].click()
        XCTAssertNotEqual(output.value as? String, first)
    }

    // App-owned output must not be written into the test runner's sandbox container.
    private func testStorage(_ name: String) -> String {
        URL(fileURLWithPath: "/private/tmp/RepoGlance-UITests", isDirectory: true)
            .appendingPathComponent(fixtureRoot.lastPathComponent, isDirectory: true)
            .appendingPathComponent(name).path
    }

    private func attachWindow(_ name: String) {
        app.activate()
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
