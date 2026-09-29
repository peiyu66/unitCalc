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
