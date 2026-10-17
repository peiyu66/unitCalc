import XCTest

final class UnitCalcUITests: XCTestCase {
    @MainActor
    func testCategorySwitchSelectsCommonUnitAndPreservesConversion() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()

        let catty = app.buttons["台斤"]
        XCTAssertTrue(catty.waitForExistence(timeout: 8))
        XCTAssertTrue(catty.isSelected)
        let weightUnits = ["台斤", "台兩", "公斤", "公克"]
        for (left, right) in zip(weightUnits, weightUnits.dropFirst()) {
            XCTAssertLessThan(app.buttons[left].frame.minX, app.buttons[right].frame.minX)
        }
        app.buttons["清除"].tap()
        app.buttons["1"].tap()
        app.buttons["台兩"].tap()
        XCTAssertTrue(app.staticTexts["計算結果 16"].waitForExistence(timeout: 2))

        app.segmentedControls.buttons["長度"].tap()
        XCTAssertTrue(app.buttons["公尺"].isSelected)
        app.segmentedControls.buttons["面積"].tap()
        XCTAssertTrue(app.buttons["台坪"].isSelected)
        app.segmentedControls.buttons["重量"].tap()
        XCTAssertTrue(catty.isSelected)

        app.segmentedControls.buttons["貨幣"].tap()
        let dollar = app.buttons["美元"]
        XCTAssertTrue(dollar.waitForExistence(timeout: 30))
        XCTAssertTrue(dollar.isSelected)
        XCTAssertLessThan(dollar.frame.minX, app.buttons["台幣"].frame.minX)
        app.buttons["台幣"].tap()
        app.segmentedControls.buttons["重量"].tap()
        app.segmentedControls.buttons["貨幣"].tap()
        XCTAssertTrue(dollar.isSelected)
    }

    @MainActor
    func testCoreControlsRemainUsableInPortraitAndLandscape() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launch()

        let clearButton = app.buttons["清除"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 8))
        XCTAssertTrue(clearButton.isHittable)
        clearButton.tap()

        let aboutButton = app.buttons["關於與隱私權"]
        XCTAssertTrue(aboutButton.isHittable)
        aboutButton.tap()
        XCTAssertTrue(app.navigationBars["關於 unitCalc"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["資料與隱私"].exists)
        XCTAssertTrue(app.staticTexts["匯率資料與免責聲明"].exists)
        XCTAssertTrue(
            app.staticTexts[
                "匯率資料僅供換算參考，不代表任何金融機構的實際交易報價；實際匯率應以交易時相關金融機構公告為準。"
            ].exists
        )
        XCTAssertTrue(app.buttons["完成"].isHittable)
        app.buttons["完成"].tap()

        app.segmentedControls.buttons["面積"].tap()
        let unitPicker = app.scrollViews["unitPicker"]
        XCTAssertTrue(unitPicker.waitForExistence(timeout: 3))
        unitPicker.swipeLeft()
        XCTAssertTrue(app.buttons["ft²"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["ft²"].isHittable)

        XCUIDevice.shared.orientation = .landscapeLeft

        let equalsButton = app.buttons["等於"]
        XCTAssertTrue(equalsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(equalsButton.isHittable)
        assertContainedInMainWindow(equalsButton, app: app)
        assertContainedInMainWindow(app.buttons["加"], app: app)
        assertContainedInMainWindow(app.buttons["清除"], app: app)

        app.buttons["1"].tap()
        app.buttons["加"].tap()
        app.buttons["2"].tap()
        equalsButton.tap()
        XCTAssertTrue(app.staticTexts["計算結果 3"].waitForExistence(timeout: 2))
    }

    // Same SDK, content and layout on both sides; only the custom top surfaces differ.
    @MainActor
    func testTopControlGlassComparisonAndInteractions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for style in ["Light", "Dark"] {
            for legacy in [true, false] {
                XCUIDevice.shared.orientation = .portrait
                app.launchArguments = ["-AppleInterfaceStyle", style]
                if legacy { app.launchArguments.append("--unitcalc-legacy-controls") }
                app.launch()
                XCTAssertTrue(app.buttons["台斤"].waitForExistence(timeout: 8))
                for (name, orientation) in [("portrait", UIDeviceOrientation.portrait),
                                             ("landscape", UIDeviceOrientation.landscapeLeft)] {
                    XCUIDevice.shared.orientation = orientation
                    let about = app.buttons["關於與隱私權"]
                    XCTAssertTrue(about.waitForExistence(timeout: 5))
                    assertContainedInMainWindow(about, app: app)
                    about.tap()
                    XCTAssertTrue(app.navigationBars["關於 unitCalc"].waitForExistence(timeout: 3))
                    app.buttons["完成"].tap()
                    // Exercise either the compact landscape menu or the native segments.
                    if app.segmentedControls.buttons["長度"].exists {
                        app.segmentedControls.buttons["長度"].tap()
                        app.segmentedControls.buttons["重量"].tap()
                    } else {
                        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "換算種類，目前為")).firstMatch.tap()
                        app.buttons["長度"].tap()
                        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "換算種類，目前為")).firstMatch.tap()
                        app.buttons["重量"].tap()
                    }
                    app.buttons["清除"].tap()
                    app.buttons["1"].tap(withNumberOfTaps: 3, numberOfTouches: 1)
                    XCTAssertTrue(app.staticTexts["計算結果 111"].waitForExistence(timeout: 2))
                    app.buttons["清除"].tap()
                    app.buttons["1"].tap()
                    app.buttons["台兩"].tap()
                    XCTAssertTrue(app.staticTexts["計算結果 16"].waitForExistence(timeout: 2))
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "\(legacy ? "before" : "glass")-\(style.lowercased())-\(name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                app.terminate()
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAdaptiveResultRotatesAndKeepsOriginalCalculation() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["清除"].waitForExistence(timeout: 8))
        app.buttons["清除"].tap()
        for key in ["1", "除", "3", "等於"] { app.buttons[key].tap() }
        let result = app.staticTexts["calculationResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        let portrait = result.label
        XCTAssertTrue(portrait.hasPrefix("計算結果 0.333"))
        assertContainedInMainWindow(result, app: app)
        captureResult(app, name: "third-portrait")
        app.buttons["複製計算紀錄"].tap()
        // The confirmation lasts 1.2 seconds; XCTest's one-second polling can miss it on iOS 17.
        XCTAssertTrue(app.buttons["已複製計算紀錄"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["等於"].waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.hasPrefix("計算結果 0.333"))
        XCTAssertGreaterThanOrEqual(result.label.count, portrait.count)
        assertContainedInMainWindow(result, app: app)
        captureResult(app, name: "third-landscape")
        for key in ["乘", "3", "等於"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 1")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(result.label, "計算結果 1")

        app.buttons["清除"].tap()
        for key in ["1", "小數點", "5", "等於"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 1.5")
        app.buttons["清除"].tap()
        app.buttons["小數點"].tap()
        XCTAssertEqual(result.label, "計算結果 0.")
        app.buttons["清除"].tap()
        for key in ["1", "小數點", "0", "0"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 1.00")
        app.buttons["等於"].tap()
        XCTAssertEqual(result.label, "計算結果 1")
    }

    @MainActor
    func testExtremeResultFixturesAcrossOrientations() throws {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        let values = ["1.234567890123e-8", "-1.234567890123e100", "1.7976931348623157e308", "5e-324", "9.99996e99"]
        for (index, value) in values.enumerated() {
            XCUIDevice.shared.orientation = .portrait
            app.launchArguments = ["--unitcalc-result-value", value]
            app.launch()
            let result = app.staticTexts["calculationResult"]
            XCTAssertTrue(result.waitForExistence(timeout: 8))
            for (name, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
                XCUIDevice.shared.orientation = orientation
                XCTAssertTrue(result.waitForExistence(timeout: 5))
                XCTAssertTrue(result.label.contains("e"), result.label)
                XCTAssertFalse(result.label.contains("…"))
                XCTAssertFalse(result.label.contains("錯誤"))
                assertContainedInMainWindow(result, app: app)
                captureResult(app, name: "extreme-\(index)-\(name)")
            }
            app.terminate()
        }
    }

    @MainActor
    func testCompleteInputKeepsLargeNumbersAcrossRotationAndRecall() throws {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["十億"].waitForExistence(timeout: 8))
        let result = app.staticTexts["calculationResult"]
        app.buttons["清除"].tap()
        app.buttons["十億"].tap()
        XCTAssertEqual(result.label, "計算結果 1,000,000,000")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(result.label, "計算結果 1,000,000,000")
        assertContainedInMainWindow(result, app: app)
        captureResult(app, name: "billion-input-portrait")
        app.buttons["等於"].tap()
        XCTAssertNotEqual(result.label, "計算結果 1,000,000,000")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["十億"].waitForExistence(timeout: 5))
        app.buttons["復原上一步"].tap()
        XCTAssertEqual(result.label, "計算結果 1,000,000,000")
        app.buttons["儲存至記憶"].tap()
        app.buttons["清除"].tap()
        app.buttons["讀取記憶"].tap()
        XCTAssertEqual(result.label, "計算結果 1,000,000,000")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["十億"].waitForExistence(timeout: 5))
        app.buttons["清除"].tap()
        XCTAssertEqual(result.label, "計算結果 0")
        for key in ["1", "2", "3", "4", "兆"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 1,234,000,000,000,000")
        captureResult(app, name: "large-input-landscape")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(result.label, "計算結果 1,234,000,000,000,000")
        captureResult(app, name: "large-input-portrait")
        app.buttons["清除"].tap()
        for key in ["1", "小數點", "2", "3", "4", "5", "6", "7", "8", "9", "0", "1", "2"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 1.23456789012")
        captureResult(app, name: "long-decimal-input-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["十億"].waitForExistence(timeout: 5))
        app.buttons["清除"].tap()
        XCTAssertEqual(result.label, "計算結果 0")
        for key in ["0", "減", "1", "2", "3", "4", "兆", "等於", "儲存至記憶", "清除", "讀取記憶"] { app.buttons[key].tap() }
        XCTAssertEqual(result.label, "計算結果 -1,234,000,000,000,000")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(result.label, "計算結果 -1,234,000,000,000,000")
        assertContainedInMainWindow(result, app: app)
        captureResult(app, name: "negative-recalled-input-portrait")
    }

    @MainActor
    private func captureResult(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assertContainedInMainWindow(
        _ element: XCUIElement,
        app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)

        let windowFrame = app.windows.firstMatch.frame
        let elementFrame = element.frame
        XCTAssertGreaterThanOrEqual(elementFrame.minX, windowFrame.minX - 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(elementFrame.minY, windowFrame.minY - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxX, windowFrame.maxX + 1, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxY, windowFrame.maxY + 1, file: file, line: line)
    }
}
