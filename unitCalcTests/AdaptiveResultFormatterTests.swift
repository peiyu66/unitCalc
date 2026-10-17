import XCTest
import UIKit
@testable import unitCalc

@MainActor
final class AdaptiveResultFormatterTests: XCTestCase {
    private func format(_ value: Double, characters: Int, locale: String = "en_US_POSIX") -> AdaptiveResultFormatter.Output {
        AdaptiveResultFormatter(locale: Locale(identifier: locale)).format(value, width: CGFloat(characters)) {
            CGFloat($0.count)
        }
    }

    func testSimpleValuesDoNotAcquireTrailingZeros() {
        for (value, expected) in [(0.0, "0"), (-0.0, "0"), (1, "1"), (1.5, "1.5"), (-1.5, "-1.5"), (1234, "1,234")] {
            XCTAssertEqual(format(value, characters: 20).text, expected)
        }
        XCTAssertEqual(format(1e20, characters: 6).text, "1e+20")
        XCTAssertEqual(format(1.5e-8, characters: 6).text, "1.5e-8")
    }

    func testLongFractionsUseAvailableWidthAndRoundHalfUp() {
        XCTAssertEqual(format(1 / 3, characters: 20).text, "0.3333333333333")
        XCTAssertEqual(format(1 / 3, characters: 5).text, "0.333")
        XCTAssertEqual(format(2 / 3, characters: 5).text, "0.667")
        XCTAssertEqual(format(-2 / 3, characters: 6).text, "-0.667")
        XCTAssertEqual(format(1.2345, characters: 5).text, "1.235")
        XCTAssertEqual(format(-1.2345, characters: 6).text, "-1.235")
        XCTAssertEqual(format(sqrt(2), characters: 8).text, "1.414214")
    }

    func testIntegerAndMantissaCarryAreMeasuredAfterRounding() {
        XCTAssertEqual(format(9.99996, characters: 6).text, "10.000")
        let carry = format(999.999996, characters: 9).text
        print("decimal carry: \(carry)")
        XCTAssertEqual(carry, "1,000.000")
        let tooNarrow = format(999.999996, characters: 8)
        XCTAssertEqual(tooNarrow.text, "1.000e+3")
        XCTAssertTrue(tooNarrow.fits)
        XCTAssertEqual(format(9.99996e99, characters: 10).text, "1.000e+100")
        XCTAssertEqual(format(999.9999999999999, characters: 30).text, "1,000.000")
    }

    func testLargeIntegersAndTinyNonzeroResultsUseScientificNotation() {
        XCTAssertEqual(format(123456789, characters: 8).text, "1.235e+8")
        XCTAssertEqual(format(-123456789, characters: 9).text, "-1.235e+8")
        XCTAssertEqual(format(1.23456789e-8, characters: 8).text, "1.235e-8")
        XCTAssertEqual(format(-1.23456789e-8, characters: 9).text, "-1.235e-8")
        XCTAssertEqual(format(Double.greatestFiniteMagnitude, characters: 10).text, "1.798e+308")
        XCTAssertEqual(format(Double.leastNonzeroMagnitude, characters: 10).text, "5e-324")
        XCTAssertEqual(format(-Double.leastNonzeroMagnitude, characters: 10).text, "-5e-324")
        XCTAssertEqual(format(.infinity, characters: 10).text, "錯誤")
        XCTAssertEqual(format(.nan, characters: 10).text, "錯誤")
    }

    func testInsufficientSpaceIsExplicitAndDoesNotLoseMinimumPrecision() {
        let result = format(1.23456789e100, characters: 4)
        XCTAssertEqual(result.text, "1.235e+100")
        XCTAssertFalse(result.fits)
        XCTAssertFalse(format(-1.23456789e100, characters: 0).fits)
        XCTAssertEqual(format(1 / 3, characters: -1).text, "3.333e-1")
    }

    func testLocaleSeparatorsAndGroupingAreMeasuredAsPartOfTheResult() {
        XCTAssertEqual(format(1234.5, characters: 20, locale: "de_DE").text, "1.234,5")
        XCTAssertEqual(format(2 / 3, characters: 5, locale: "de_DE").text, "0,667")
        XCTAssertEqual(format(1.23456789e-8, characters: 8, locale: "de_DE").text, "1,235e-8")
        for locale in ["zh_TW", "fr_FR", "hi_IN", "ar_EG"] {
            for value: Double in [1234567.891234, -2.0 / 3.0, 1.23456789e-8] {
                let result = format(value, characters: 14, locale: locale)
                XCTAssertTrue(result.fits, "\(locale): \(result.text)")
                XCTAssertLessThanOrEqual(result.text.count, 14)
            }
        }
        // App default intentionally remains compatible with its existing POSIX input/log.
        XCTAssertEqual(format(1234.5, characters: 20).text, "1,234.5")
    }

    func testActualRoundedSystemFontWidthsKeepTheirSize() {
        for size: CGFloat in [56, 88, 114.4, 148, 196] {
            let base = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
            let font = UIFont(descriptor: base.fontDescriptor.withDesign(.rounded)!, size: size)
            let measure: (String) -> CGFloat = { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }
            for width: CGFloat in [240, 339, 600, 800, 1100, 1300] {
                for value: Double in [0, 1.5, -1.5, 1 / 3, -123456789, 1.23456789e-8, .greatestFiniteMagnitude, .leastNonzeroMagnitude] {
                    let result = AdaptiveResultFormatter().format(value, width: width, measure: measure)
                    XCTAssertEqual(result.fits, measure(result.text) <= width)
                    XCTAssertFalse(result.text.contains("…"))
                    XCTAssertEqual(font.pointSize, size)
                }
            }
            if size == 88 {
                print("88pt rounded monospaced: 1.234e+308 width = \(measure("1.234e+308")); 1.234e-8 width = \(measure("1.234e-8"))")
                XCTAssertGreaterThan(measure("1.234e+308"), 339)
            }
        }
    }

    func testResultViewOnlyScalesShortestNotationAndRestoresMaximumFont() {
        let view = makeResultView(.greatestFiniteMagnitude, width: 339)
        XCTAssertEqual(view.numberLabel.text, "1.798e+308")
        XCTAssertTrue(view.usesEmergencyScaling)
        XCTAssertLessThan(view.numberLabel.font.pointSize, 88)
        assertRenderedResultFits(view)
        // The selected size is the largest fitting size, rather than a fixed smaller style.
        let larger = view.numberLabel.font.withSize(view.numberLabel.font.pointSize + 0.05)
        XCTAssertGreaterThan(ResultNumberView.width(of: view.numberLabel.text!, font: larger), 337)
        view.frame.size.width = 1300
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertFalse(view.usesEmergencyScaling)
        XCTAssertEqual(view.numberLabel.font.pointSize, 88)
        XCTAssertGreaterThan(view.numberLabel.text!.count, "1.798e+308".count)
        assertRenderedResultFits(view)
        view.frame.size.width = 339
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertEqual(view.numberLabel.text, "1.798e+308")
        XCTAssertTrue(view.usesEmergencyScaling)
        assertRenderedResultFits(view)
    }

    func testResultViewUsesMaximumFontForOrdinaryRoundedValues() {
        for value: Double in [0, -0, 1.5, -1.5, 1 / 3, 2 / 3, sqrt(2)] {
            let view = makeResultView(value, width: 339)
            XCTAssertFalse(view.usesEmergencyScaling)
            XCTAssertEqual(view.numberLabel.font.pointSize, 88)
            assertRenderedResultFits(view)
        }
        let view = makeResultView(1 / 3, width: 339)
        let portrait = view.numberLabel.text!
        view.frame.size.width = 800
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertGreaterThan(view.numberLabel.text!.count, portrait.count)
        XCTAssertEqual(view.numberLabel.font.pointSize, 88)
    }

    func testResultViewHandlesAllSizesSignsExponentsAndDynamicTypeWithoutTruncation() {
        for size: CGFloat in [56, 88, 114.4, 148, 196, 254.8] {
            for width: CGFloat in [160, 240, 339, 600, 800, 1100, 1300] {
                for value: Double in [0, 1.5, -1.5, 1 / 3, -123456789, 1.23456789e-8,
                                      -1.23456789e-8, -1.23456789e100, .greatestFiniteMagnitude,
                                      .leastNonzeroMagnitude, -.greatestFiniteMagnitude, -.leastNonzeroMagnitude] {
                    let view = makeResultView(value, width: width, fontSize: size)
                    assertRenderedResultFits(view)
                    let atNormalSize = AdaptiveResultFormatter().format(value, width: width - 2) {
                        ResultNumberView.width(of: $0, font: view.maximumFont)
                    }
                    XCTAssertEqual(view.numberLabel.text, atNormalSize.text)
                    XCTAssertEqual(view.usesEmergencyScaling, !atNormalSize.fits)
                    if atNormalSize.fits { XCTAssertEqual(view.numberLabel.font.pointSize, size) }
                }
            }
        }
    }

    func testResultViewPreservesEditingLiteralButNeverWritesItBack() {
        for (value, text) in [(0.0, "0."), (1.0, "1.00"), (1.5, "1.50")] {
            let view = makeResultView(value, width: 339, inputText: text)
            XCTAssertEqual(view.numberLabel.text, text)
            XCTAssertEqual(view.numberLabel.font.pointSize, 88)
            view.configure(value: value, inputText: nil, errorText: nil, fontSize: 88, weight: .regular)
            view.layoutIfNeeded()
            XCTAssertEqual(view.numberLabel.text, value == 0 ? "0" : (value == 1 ? "1" : "1.5"))
        }
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for key in ["1", ".", "2", "3", "4", "5", "6", "7", "8", "9"] { calculator.keyin(key, byUser: true) }
        let original = calculator.valueCurrent
        let text = calculator.textCurrent
        let view = makeResultView(original, width: 240, inputText: text)
        assertRenderedResultFits(view)
        XCTAssertEqual(calculator.textCurrent, text)
        XCTAssertEqual(calculator.valueCurrent, original)
        calculator.keyin("0", byUser: true)
        XCTAssertEqual(calculator.textCurrent, text + "0")
        XCTAssertEqual(calculator.valueCurrent, original)
    }

    func testLargeNumberKeysRemainCompleteUntilEvaluation() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        calculator.keyin("十億", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "1,000,000,000")
        XCTAssertEqual(calculator.valueCurrent, 1e9)
        let view = makeResultView(calculator.valueCurrent, width: 339, inputText: calculator.inputDisplayText)
        XCTAssertEqual(view.numberLabel.text, "1,000,000,000")
        XCTAssertTrue(view.usesEmergencyScaling)
        assertRenderedResultFits(view)
        calculator.keyin("=", byUser: true)
        XCTAssertNil(calculator.inputDisplayText)
        view.configure(value: calculator.valueCurrent, inputText: calculator.inputDisplayText,
                       errorText: nil, fontSize: 88, weight: .regular)
        view.layoutIfNeeded()
        XCTAssertEqual(view.numberLabel.text, "1e+9")
        XCTAssertFalse(view.usesEmergencyScaling)
        calculator.keyin("C", byUser: true)
        for digit in "1234567890123" { calculator.keyin(String(digit), byUser: true) }
        calculator.keyin("兆", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "1,234,567,890,123,000,000,000,000")
        XCTAssertEqual(calculator.valueCurrent, 1_234_567_890_123 * 1e12)
        XCTAssertFalse(calculator.isKeyEnabled("1"))
    }

    func testCompleteInputScalesWithoutRoundingAndRestoresSizeWhenWider() {
        for (value, text) in [(1.23456789012, "1.23456789012"),
                              (1234e12, "1,234,000,000,000,000"),
                              (-1234e12, "-1,234,000,000,000,000"), (1.0, "1.00000000000")] {
            let view = makeResultView(value, width: 160, inputText: text)
            XCTAssertEqual(view.numberLabel.text, text)
            XCTAssertTrue(view.usesEmergencyScaling)
            assertRenderedResultFits(view)
            view.frame.size.width = 1600
            view.setNeedsLayout()
            view.layoutIfNeeded()
            XCTAssertEqual(view.numberLabel.text, text)
            XCTAssertFalse(view.usesEmergencyScaling)
            XCTAssertEqual(view.numberLabel.font.pointSize, 88)
            view.frame.size.width = 160
            view.setNeedsLayout()
            view.layoutIfNeeded()
            XCTAssertEqual(view.numberLabel.text, text)
            assertRenderedResultFits(view)
        }
    }

    func testMemorySaveAndClearDoNotChangeInputOrResultMode() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for key in ["1", ".", "0", "0", "ms", "mc"] { calculator.keyin(key, byUser: true) }
        XCTAssertEqual(calculator.inputDisplayText, "1.00")
        calculator.keyin("=", byUser: true)
        for key in ["ms", "mc"] {
            calculator.keyin(key, byUser: true)
            XCTAssertNil(calculator.inputDisplayText)
        }
        calculator.keyin("√", byUser: true)
        XCTAssertNotNil(calculator.valueInput) // Unary results cannot be classified by valueInput alone.
        calculator.keyin("ms", byUser: true)
        XCTAssertNil(calculator.inputDisplayText)
    }

    func testUndoRestoresInputLiteralAndClearErrorConversionRestoreResultMode() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        // Existing CE clears zero after equals; a unary undo restores the entered literal.
        for key in ["0", ".", "0", "0", "=", "CE"] { calculator.keyin(key, byUser: true) }
        XCTAssertNil(calculator.inputDisplayText)
        XCTAssertEqual(calculator.valueCurrent, 0)
        for key in ["C", "0", ".", "0", "0", "x²", "CE"] { calculator.keyin(key, byUser: true) }
        XCTAssertEqual(calculator.inputDisplayText, "0.00")
        calculator.keyin("3", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "0.003")
        XCTAssertEqual(calculator.valueCurrent, 0.003)
        calculator.keyin("C", byUser: true)
        for key in ["1", "2", "3", "4", "兆", "=", "CE"] { calculator.keyin(key, byUser: true) }
        XCTAssertEqual(calculator.inputDisplayText, "1,234,000,000,000,000")
        XCTAssertEqual(calculator.valueCurrent, 1234e12)
        for key in ["C", "2", ".", "0", "0", "x²", "CE"] { calculator.keyin(key, byUser: true) }
        XCTAssertEqual(calculator.inputDisplayText, "2.00")
        XCTAssertEqual(calculator.valueCurrent, 2)
        calculator.keyin("C", byUser: true)
        XCTAssertNil(calculator.inputDisplayText)
        for key in ["1", "/", "0", "="] { calculator.keyin(key, byUser: true) }
        XCTAssertNil(calculator.inputDisplayText)
        XCTAssertNotNil(calculator.calculationErrorDescription)
        calculator.keyin("2", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "2")
        XCTAssertNil(calculator.calculationErrorDescription)
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公克")
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公斤")
        XCTAssertNil(calculator.inputDisplayText)
        XCTAssertEqual(calculator.valueCurrent, 0.002)
    }

    func testRecallExpandsShortestDoubleRepresentationWithoutRounding() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for value: Double in [0, -0, 1.5, -1.5, 1 / 3, 1.23e-8, -1234e12, 1.234567890123e24,
                              .greatestFiniteMagnitude, -.greatestFiniteMagnitude,
                              .leastNonzeroMagnitude, -.leastNonzeroMagnitude] {
            calculator.valueMemory = value
            calculator.keyin("mr", byUser: true)
            let text = calculator.inputDisplayText!
            XCTAssertFalse(text.lowercased().contains("e"))
            XCTAssertEqual(Double(text.replacingOccurrences(of: ",", with: "")), value)
            XCTAssertEqual(calculator.valueCurrent, value)
            let view = makeResultView(value, width: 339, inputText: text)
            XCTAssertEqual(view.numberLabel.text, text)
            assertRenderedResultFits(view)
            calculator.keyin("=", byUser: true)
            XCTAssertNil(calculator.inputDisplayText)
            XCTAssertEqual(calculator.valueCurrent, value)
        }
    }

    func testTypingAfterRecallAppendsToDecimalInsteadOfScientificExponent() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        calculator.valueMemory = 1.23e-8
        calculator.keyin("mr", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "0.0000000123")
        XCTAssertFalse(calculator.isKeyEnabled("."))
        XCTAssertTrue(calculator.isKeyEnabled("4"))
        calculator.keyin("4", byUser: true)
        XCTAssertEqual(calculator.inputDisplayText, "0.00000001234")
        XCTAssertEqual(calculator.valueCurrent, 1.234e-8)
        calculator.valueMemory = 1e20
        calculator.keyin("mr", byUser: true)
        XCTAssertFalse(calculator.isKeyEnabled("1"))
    }

    func testEvaluatedResultsKeepExistingFormatAfterEveryInputPath() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for keys in [["1", "/", "3", "="], ["1", "2", "3", "4", "兆", "="], ["1", ".", "5", "="]] {
            calculator.keyin("C", byUser: true)
            for key in keys { calculator.keyin(key, byUser: true) }
            let originalValue = calculator.valueCurrent
            let history = calculator.logText
            XCTAssertNil(calculator.inputDisplayText)
            for width: CGFloat in [160, 339, 800, 1300] {
                let view = makeResultView(originalValue, width: width, inputText: calculator.inputDisplayText)
                let expected = AdaptiveResultFormatter().format(originalValue, width: width - 2) {
                    ResultNumberView.width(of: $0, font: view.maximumFont)
                }
                XCTAssertEqual(view.numberLabel.text, expected.text)
                XCTAssertEqual(view.usesEmergencyScaling, !expected.fits)
            }
            XCTAssertEqual(calculator.valueCurrent, originalValue)
            XCTAssertEqual(calculator.logText, history)
        }
    }

    private func makeResultView(_ value: Double, width: CGFloat, fontSize: CGFloat = 88,
                                inputText: String? = nil) -> ResultNumberView {
        let view = ResultNumberView(frame: CGRect(x: 0, y: 0, width: width, height: 300))
        view.configure(value: value, inputText: inputText, errorText: nil, fontSize: fontSize, weight: .regular)
        view.layoutIfNeeded()
        return view
    }

    private func assertRenderedResultFits(_ view: ResultNumberView, file: StaticString = #filePath, line: UInt = #line) {
        let label = view.numberLabel
        XCTAssertLessThanOrEqual(ResultNumberView.width(of: label.text!, font: label.font), label.bounds.width, file: file, line: line)
        XCTAssertFalse(label.adjustsFontSizeToFitWidth, file: file, line: line)
        XCTAssertEqual(label.minimumScaleFactor, 1, file: file, line: line)
        XCTAssertFalse(label.text!.contains("…"), file: file, line: line)
        XCTAssertEqual(label.accessibilityLabel, "計算結果 \(label.text!)", file: file, line: line)
    }

    func testFormattingCannotChangeOperandsMemoryHistoryOrSubsequentCalculation() {
        let calculator = Calculator(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for key in ["1", "/", "3", "=", "ms"] { calculator.keyin(key, byUser: true) }
        let original = calculator.valueCurrent
        let operand = calculator.valueOperant
        let input = calculator.valueInput
        let currentText = calculator.textCurrent
        let history = calculator.logText
        let count = calculator.opLog.count
        for width in [5, 8, 15, 30, 5] {
            _ = format(calculator.valueCurrent, characters: width)
        }
        XCTAssertEqual(calculator.valueCurrent, original)
        XCTAssertEqual(calculator.valueOperant, operand)
        XCTAssertEqual(calculator.valueInput, input)
        XCTAssertEqual(calculator.valueMemory, original)
        XCTAssertEqual(calculator.textCurrent, currentText)
        XCTAssertEqual(calculator.logText, history)
        XCTAssertEqual(calculator.opLog.count, count)
        XCTAssertTrue(history.contains("0.3333333333333"))
        for key in ["*", "3", "="] { calculator.keyin(key, byUser: true) }
        XCTAssertEqual(calculator.valueCurrent, 1)
        calculator.keyin("mr", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, original)
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公克")
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公斤")
        XCTAssertEqual(calculator.valueCurrent, original / 1000, accuracy: 1e-18)
    }
}
