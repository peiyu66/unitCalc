import XCTest
@testable import unitCalc

@MainActor
final class CalculatorTests: XCTestCase {
    func testBasicArithmeticAndMemory() {
        let calculator = makeCalculator()

        press(["1", "2", "+", "7", "=", "ms"], on: calculator)

        XCTAssertEqual(calculator.valueCurrent, 19, accuracy: 1e-12)
        XCTAssertEqual(calculator.valueMemory, 19)
        XCTAssertEqual(calculator.textCurrent, "19")
    }

    func testDivisionByZeroShowsRecoverableError() {
        let calculator = makeCalculator()

        press(["8", "/", "0", "="], on: calculator)

        XCTAssertEqual(calculator.textCurrent, "錯誤")
        XCTAssertEqual(calculator.calculationErrorDescription, "無法除以零")

        calculator.keyin("3", byUser: true)

        XCTAssertNil(calculator.calculationErrorDescription)
        XCTAssertEqual(calculator.valueCurrent, 3, accuracy: 1e-12)
        XCTAssertEqual(calculator.textCurrent, "3")
    }

    func testNegativeSquareRootShowsError() {
        let calculator = makeCalculator()

        calculator.valueCurrent = -1
        calculator.valueInput = -1
        calculator.keyin("√", byUser: true)

        XCTAssertEqual(calculator.textCurrent, "錯誤")
        XCTAssertEqual(calculator.calculationErrorDescription, "負數沒有實數平方根")
    }

    func testOutputPreservesSmallMeaningfulFractions() {
        let calculator = makeCalculator()

        XCTAssertEqual(calculator.outputText(0.00001), "1e-05")
        XCTAssertEqual(calculator.outputText(1.0 / 3.0), "0.3333333333333")
    }

    func testKeyEnablementGuardsInvalidSequences() {
        let calculator = makeCalculator()

        XCTAssertFalse(calculator.isKeyEnabled("mc"))
        XCTAssertFalse(calculator.isKeyEnabled("mr"))

        press(["1", ".", "2"], on: calculator)
        XCTAssertFalse(calculator.isKeyEnabled("."))

        calculator.keyin("百萬", byUser: true)
        XCTAssertFalse(calculator.isKeyEnabled("2"))
        XCTAssertFalse(calculator.isKeyEnabled("十萬"))

        calculator.keyin("C", byUser: true)
        press(["4", "+"], on: calculator)
        XCTAssertFalse(calculator.isKeyEnabled("*"))
        XCTAssertFalse(calculator.isKeyEnabled("√"))
        XCTAssertFalse(calculator.isKeyEnabled("="))

        calculator.textCurrent = String(repeating: "1", count: 13)
        calculator.valueCurrent = 1
        calculator.valueInput = 1
        calculator.textLastKey = "1"
        XCTAssertFalse(calculator.isKeyEnabled("2"))
    }

    func testPowerOfTenShortcutsStartAndScaleValues() {
        let calculator = makeCalculator()

        calculator.keyin("十萬", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 100_000, accuracy: 1e-12)
        XCTAssertEqual(calculator.textCurrent, "100,000")

        calculator.keyin("C", byUser: true)
        press(["2", "百萬"], on: calculator)
        XCTAssertEqual(calculator.valueCurrent, 2_000_000, accuracy: 1e-12)
        XCTAssertEqual(calculator.textCurrent, "2,000,000")
    }

    func testMemoryRecallClearAndDoubleClearBehavior() {
        let calculator = makeCalculator()

        press(["2", "+", "3", "=", "ms", "C"], on: calculator)
        XCTAssertEqual(calculator.valueMemory, 5)
        XCTAssertTrue(calculator.hasHistory)

        calculator.keyin("mr", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 5, accuracy: 1e-12)
        XCTAssertEqual(calculator.textCurrent, "5")

        calculator.keyin("C", byUser: true)
        calculator.keyin("C", byUser: true)
        XCTAssertNil(calculator.valueMemory)
        XCTAssertFalse(calculator.hasHistory)
        XCTAssertEqual(calculator.textCurrent, "0")
    }

    func testClearEntryRestoresPriorOperation() {
        let calculator = makeCalculator()

        press(["5", "+", "3", "="], on: calculator)
        XCTAssertEqual(calculator.valueCurrent, 8, accuracy: 1e-12)

        calculator.keyin("CE", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 3, accuracy: 1e-12)
        XCTAssertEqual(calculator.valueOperant, 5, accuracy: 1e-12)
        XCTAssertEqual(calculator.textOperator, "+")

        calculator.keyin("CE", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 5, accuracy: 1e-12)
        XCTAssertNil(calculator.valueInput)

        let freshCalculator = makeCalculator()
        press(["9", "CE"], on: freshCalculator)
        XCTAssertEqual(freshCalculator.valueCurrent, 0, accuracy: 1e-12)
        XCTAssertEqual(freshCalculator.textCurrent, "0")
    }

    func testUnaryPowerAndRootOperations() {
        let calculator = makeCalculator()

        press(["3", "x³"], on: calculator)
        XCTAssertEqual(calculator.valueCurrent, 27, accuracy: 1e-12)

        calculator.keyin("∛", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 3, accuracy: 1e-12)

        calculator.keyin("x²", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 9, accuracy: 1e-12)

        calculator.keyin("√", byUser: true)
        XCTAssertEqual(calculator.valueCurrent, 3, accuracy: 1e-12)
    }

    func testWeightConversionRoundTrip() {
        let calculator = makeCalculator()
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公克")
        press(["1", "0", "0", "0"], on: calculator)

        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公斤")
        XCTAssertEqual(calculator.valueCurrent, 1, accuracy: 1e-12)

        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公克")
        XCTAssertEqual(calculator.valueCurrent, 1000, accuracy: 1e-9)
    }

    func testWeightConversionsMatchReferenceValues() {
        let references: [(unit: String, grams: Double)] = [
            ("公斤", 1_000),
            ("台斤", 600),
            ("台兩", 37.5),
            ("英磅", 453.59237),
            ("盎司", 28.349523125)
        ]

        for reference in references {
            assertConversion(
                1,
                category: "重量",
                from: reference.unit,
                to: "公克",
                equals: reference.grams
            )
            assertConversion(
                reference.grams,
                category: "重量",
                from: "公克",
                to: reference.unit,
                equals: 1
            )
        }
    }

    func testLengthConversionsMatchReferenceValues() {
        let references: [(unit: String, meters: Double)] = [
            ("公分", 0.01),
            ("台尺", 10.0 / 33.0),
            ("台寸", 1.0 / 33.0),
            ("英尺", 0.3048),
            ("英寸", 0.0254)
        ]

        for reference in references {
            assertConversion(
                1,
                category: "長度",
                from: reference.unit,
                to: "公尺",
                equals: reference.meters
            )
            assertConversion(
                reference.meters,
                category: "長度",
                from: "公尺",
                to: reference.unit,
                equals: 1
            )
        }
    }

    func testAreaConversionsMatchReferenceValues() {
        let references: [(unit: String, squareMeters: Double)] = [
            ("台坪", 400.0 / 121.0),
            ("台畝", 12_000.0 / 121.0),
            ("台分", 117_360.0 / 121.0),
            ("台甲", 1_173_600.0 / 121.0),
            ("公頃", 10_000),
            ("ft²", 0.09290304)
        ]

        for reference in references {
            assertConversion(
                1,
                category: "面積",
                from: reference.unit,
                to: "m²",
                equals: reference.squareMeters
            )
            assertConversion(
                reference.squareMeters,
                category: "面積",
                from: "m²",
                to: reference.unit,
                equals: 1
            )
        }
    }

    func testEveryStaticConversionPairMatchesReferenceValues() throws {
        let referenceValues: [String: [String: Double]] = [
            "重量": [
                "公克": 1,
                "公斤": 1_000,
                "台斤": 600,
                "台兩": 37.5,
                "英磅": 453.59237,
                "盎司": 28.349523125
            ],
            "長度": [
                "公尺": 1,
                "公分": 0.01,
                "台尺": 10.0 / 33.0,
                "台寸": 1.0 / 33.0,
                "英尺": 0.3048,
                "英寸": 0.0254
            ],
            "面積": [
                "台坪": 400.0 / 121.0,
                "台畝": 12_000.0 / 121.0,
                "台分": 117_360.0 / 121.0,
                "台甲": 1_173_600.0 / 121.0,
                "m²": 1,
                "公頃": 10_000,
                "ft²": 0.09290304
            ]
        ]
        let sample = 123.456789

        for (category, units) in referenceValues {
            for (source, sourceValue) in units {
                for (destination, destinationValue) in units where destination != source {
                    let converted = convert(
                        sample,
                        category: category,
                        from: source,
                        to: destination
                    )
                    let expected = sample * sourceValue / destinationValue
                    XCTAssertEqual(
                        converted,
                        expected,
                        accuracy: relativeAccuracy(for: expected),
                        "\(category)：\(source) → \(destination) 與基準值不一致"
                    )
                }
            }
        }
    }

    func testCrossCategorySwitchPreservesValueAndRecordsTransition() {
        let calculator = makeCalculator()
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公斤")
        press(["2"], on: calculator)

        calculator.unitConvert(pickerCat: "面積", pickerUnit: "m²")

        XCTAssertEqual(calculator.valueCurrent, 2, accuracy: 1e-12)
        XCTAssertEqual(calculator.cat, "面積")
        XCTAssertEqual(calculator.unit, "m²")
        XCTAssertEqual(calculator.logText, "2公斤; 重量→面積")
    }

    func testZeroAndInvalidUnitSelectionsAreSafe() {
        let calculator = makeCalculator()
        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公克")

        calculator.unitConvert(pickerCat: "重量", pickerUnit: "公斤")
        XCTAssertEqual(calculator.valueCurrent, 0, accuracy: 1e-12)
        XCTAssertEqual(calculator.textCurrent, "0")
        XCTAssertEqual(calculator.unit, "公斤")
        XCTAssertFalse(calculator.hasHistory)

        calculator.unitConvert(pickerCat: "未知", pickerUnit: "公尺")
        calculator.unitConvert(pickerCat: "長度", pickerUnit: "未知")
        XCTAssertEqual(calculator.cat, "重量")
        XCTAssertEqual(calculator.unit, "公斤")
        XCTAssertEqual(calculator.valueCurrent, 0, accuracy: 1e-12)
    }

    func testCurrencyFixtureConvertsEveryPairAtCashSellingRates() throws {
        let calculator = makeCalculator()
        calculator.currency = try calculator.makeCurrencyMatrix(from: Self.bankOfTaiwanFixture)
        calculator.factors = calculator.currency + calculator.metric
        let currencies = try XCTUnwrap(calculator.units["貨幣"])
        let twdValues: [String: Double] = [
            "台幣": 1,
            "美元": 31.88,
            "日圓": 0.20110,
            "歐元": 37.14,
            "英鎊": 43.71,
            "韓元": 0.02511,
            "越南盾": 0.00138,
            "港幣": 4.08,
            "人民幣": 4.763
        ]
        let sample = 12_345.6789

        for source in currencies {
            for destination in currencies where destination != source {
                let sourceValue = try XCTUnwrap(twdValues[source])
                let destinationValue = try XCTUnwrap(twdValues[destination])
                let converted = convert(
                    sample,
                    category: "貨幣",
                    from: source,
                    to: destination,
                    calculator: calculator
                )
                let expected = sample * sourceValue / destinationValue
                XCTAssertEqual(
                    converted,
                    expected,
                    accuracy: relativeAccuracy(for: expected),
                    "貨幣：\(source) → \(destination) 與牌告賣出匯率不一致"
                )
            }
        }
    }

    func testBOTParserUsesNamedColumnsInsteadOfFixedSpacing() throws {
        let calculator = makeCalculator()
        let fixture = """
        Currency Rate Cash Spot Forward Rate Cash Spot Forward
        USD Buying 31.21000 31.53500 31.54900 Selling 31.88000 31.68500 31.65300
        """

        let quote = try XCTUnwrap(calculator.parseBOTQuote(fixture, code: "USD"))

        XCTAssertEqual(quote.cashBuying, 31.21, accuracy: 1e-12)
        XCTAssertEqual(quote.spotBuying, 31.535, accuracy: 1e-12)
        XCTAssertEqual(quote.cashSelling, 31.88, accuracy: 1e-12)
        XCTAssertEqual(quote.spotSelling, 31.685, accuracy: 1e-12)
    }

    func testBOTParserFallsBackToSpotWhenCashRateIsZero() throws {
        let calculator = makeCalculator()
        let fixture = "KRW Buying 0.00000 0.02121 Selling 0.00000 0.02511"

        let quote = try XCTUnwrap(calculator.parseBOTQuote(fixture, code: "KRW"))

        XCTAssertEqual(quote.cashBuying, 0.02121, accuracy: 1e-12)
        XCTAssertEqual(quote.cashSelling, 0.02511, accuracy: 1e-12)
    }

    func testBOTFixtureBuildsAValidReciprocalMatrix() throws {
        let calculator = makeCalculator()
        let fixture = """
        USD Buying 31.21000 31.53500 Selling 31.88000 31.68500
        JPY Buying 0.18830 0.19510 Selling 0.20110 0.20010
        EUR Buying 35.80000 36.31500 Selling 37.14000 36.91500
        GBP Buying 41.59000 42.48500 Selling 43.71000 43.11500
        KRW Buying 0.02121 0.00000 Selling 0.02511 0.00000
        VND Buying 0.00097 0.00000 Selling 0.00138 0.00000
        HKD Buying 3.87600 3.99700 Selling 4.08000 4.06700
        CNY Buying 4.60100 4.66800 Selling 4.76300 4.72800
        """

        let matrix = try calculator.makeCurrencyMatrix(from: fixture)

        XCTAssertTrue(calculator.isValidCurrencyMatrix(matrix))
        XCTAssertEqual(matrix[0][0][1].f0 / matrix[0][0][1].f1, 1 / 31.88, accuracy: 1e-12)
        XCTAssertEqual(matrix[0][1][0].f0 / matrix[0][1][0].f1, 31.88, accuracy: 1e-12)
    }

    func testCurrencyMatrixRejectsNonPositiveOrNonReciprocalRates() {
        let calculator = makeCalculator()
        let count = calculator.units["貨幣"]?.count ?? 0
        var valid = Array(
            repeating: Array(repeating: Calculator.p(f0: 1, f1: 1), count: count),
            count: count
        )

        XCTAssertTrue(calculator.isValidCurrencyMatrix([valid]))

        valid[0][1] = Calculator.p(f0: 0, f1: 1)
        XCTAssertFalse(calculator.isValidCurrencyMatrix([valid]))

        valid[0][1] = Calculator.p(f0: 2, f1: 1)
        XCTAssertFalse(calculator.isValidCurrencyMatrix([valid]))
    }

    func testFreshCacheAvoidsNetworkAndRestoresSource() async throws {
        URLProtocolStub.handler = { _ in
            throw URLError(.badServerResponse)
        }
        defer { URLProtocolStub.handler = nil }

        let defaults = makeDefaults()
        let timestamp = Date()
        let matrix = identityCurrencyMatrix()
        defaults.set(timestamp, forKey: "currencyTime")
        defaults.set("測試快取", forKey: "currencySource")
        defaults.set(try JSONEncoder().encode(matrix), forKey: "currencyRate")
        let calculator = Calculator(defaults: defaults, session: makeStubSession())

        await calculator.activate()

        XCTAssertEqual(calculator.currencySource, "測試快取")
        XCTAssertEqual(calculator.currencyTime, timestamp)
        XCTAssertNil(calculator.currencyErrorDescription)
    }

    func testBankOfTaiwanIsUsedWhenPrimaryResponsesAreValid() async {
        URLProtocolStub.handler = { request in
            if request.url?.path.contains("/fltxt/") == true {
                return .text(Self.bankOfTaiwanFixture)
            }
            return .text("最新掛牌時間：<span class=\"time\">2026/08/31 06:31</span>")
        }
        defer { URLProtocolStub.handler = nil }

        let calculator = Calculator(defaults: makeDefaults(), session: makeStubSession())

        await calculator.activate()

        XCTAssertEqual(calculator.currencySource, "台灣銀行")
        XCTAssertNotNil(calculator.currencyTime)
        XCTAssertNil(calculator.currencyErrorDescription)
        XCTAssertTrue(calculator.isValidCurrencyMatrix(calculator.currency))
    }

    func testBankFailureFallsBackToCentralBankReferenceRates() async {
        URLProtocolStub.handler = { request in
            if request.url?.host == "cpx.cbc.gov.tw" {
                return .json(Self.centralBankFixture)
            }
            return .status(503)
        }
        defer { URLProtocolStub.handler = nil }

        let calculator = Calculator(defaults: makeDefaults(), session: makeStubSession())

        await calculator.activate()

        XCTAssertEqual(calculator.currencySource, "央行參考")
        XCTAssertNotNil(calculator.currencyTime)
        XCTAssertNil(calculator.currencyErrorDescription)
        XCTAssertTrue(calculator.isValidCurrencyMatrix(calculator.currency))
    }

    func testAllSourcesFailWithoutDiscardingStaleCache() async throws {
        URLProtocolStub.handler = { _ in .status(503) }
        defer { URLProtocolStub.handler = nil }

        let defaults = makeDefaults()
        let timestamp = Date(timeIntervalSinceNow: -20_000)
        defaults.set(timestamp, forKey: "currencyTime")
        defaults.set("舊快取", forKey: "currencySource")
        defaults.set(
            try JSONEncoder().encode(identityCurrencyMatrix()),
            forKey: "currencyRate"
        )
        let calculator = Calculator(defaults: defaults, session: makeStubSession())

        await calculator.activate()

        XCTAssertEqual(calculator.currencySource, "舊快取")
        XCTAssertEqual(calculator.currencyTime, timestamp)
        XCTAssertNotNil(calculator.currencyErrorDescription)
        XCTAssertTrue(calculator.currencyErrorDescription?.contains("臺灣銀行") == true)
        XCTAssertTrue(calculator.currencyErrorDescription?.contains("中央銀行") == true)
    }

    func testCorruptCacheIsReplacedAndPersisted() async throws {
        let defaults = makeDefaults()
        defaults.set(Date(), forKey: "currencyTime")
        defaults.set("損毀快取", forKey: "currencySource")
        defaults.set(Data([0xFF]), forKey: "currencyRate")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let timestamp = formatter.string(from: Date())

        URLProtocolStub.handler = { request in
            if request.url?.path.contains("/fltxt/") == true {
                return .text(Self.bankOfTaiwanFixture)
            }
            return .text("最新掛牌時間：<span class=\"time\">\(timestamp)</span>")
        }
        defer { URLProtocolStub.handler = nil }

        let calculator = Calculator(defaults: defaults, session: makeStubSession())
        await calculator.activate()

        XCTAssertEqual(calculator.currencySource, "台灣銀行")
        XCTAssertNil(calculator.currencyErrorDescription)
        XCTAssertTrue(calculator.isValidCurrencyMatrix(calculator.currency))
        XCTAssertNotNil(defaults.data(forKey: "currencyRate"))

        URLProtocolStub.handler = { _ in throw URLError(.notConnectedToInternet) }
        let restored = Calculator(defaults: defaults, session: makeStubSession())
        await restored.activate()

        XCTAssertEqual(restored.currencySource, "台灣銀行")
        XCTAssertNil(restored.currencyErrorDescription)
        XCTAssertTrue(restored.isValidCurrencyMatrix(restored.currency))
    }

    private func makeCalculator() -> Calculator {
        Calculator(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "CalculatorTests.\(UUID().uuidString)")!
    }

    private func makeStubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func assertConversion(
        _ value: Double,
        category: String,
        from source: String,
        to destination: String,
        equals expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = convert(value, category: category, from: source, to: destination)
        XCTAssertEqual(
            result,
            expected,
            accuracy: relativeAccuracy(for: expected),
            "\(category)：\(value) \(source) → \(destination)",
            file: file,
            line: line
        )
    }

    private func convert(
        _ value: Double,
        category: String,
        from source: String,
        to destination: String,
        calculator: Calculator? = nil
    ) -> Double {
        let calculator = calculator ?? makeCalculator()
        calculator.unitConvert(pickerCat: category, pickerUnit: source)
        calculator.valueCurrent = value
        calculator.valueInput = value
        calculator.textCurrent = calculator.outputText(value)
        calculator.unitConvert(pickerCat: category, pickerUnit: destination)
        return calculator.valueCurrent
    }

    private func relativeAccuracy(for expected: Double) -> Double {
        max(abs(expected) * 1e-10, 1e-10)
    }

    private func identityCurrencyMatrix() -> [[[Calculator.p]]] {
        let count = 9
        return [Array(
            repeating: Array(repeating: Calculator.p(f0: 1, f1: 1), count: count),
            count: count
        )]
    }

    private func press(_ keys: [String], on calculator: Calculator) {
        for key in keys {
            calculator.keyin(key, byUser: true)
        }
    }

    private static let centralBankFixture = """
    {"data":{"dataSets":[["20260831","31.5","155","1.3","7.8","1400","1","1","7.2","1","1","1","1","1","1.16","1","1","1","26000"]]}}
    """

    private static let bankOfTaiwanFixture = """
    USD Buying 31.21000 31.53500 Selling 31.88000 31.68500
    JPY Buying 0.18830 0.19510 Selling 0.20110 0.20010
    EUR Buying 35.80000 36.31500 Selling 37.14000 36.91500
    GBP Buying 41.59000 42.48500 Selling 43.71000 43.11500
    KRW Buying 0.02121 0.00000 Selling 0.02511 0.00000
    VND Buying 0.00097 0.00000 Selling 0.00138 0.00000
    HKD Buying 3.87600 3.99700 Selling 4.08000 4.06700
    CNY Buying 4.60100 4.66800 Selling 4.76300 4.72800
    """
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct StubResponse {
        let statusCode: Int
        let contentType: String
        let data: Data

        static func status(_ statusCode: Int) -> StubResponse {
            StubResponse(statusCode: statusCode, contentType: "text/plain", data: Data())
        }

        static func json(_ value: String) -> StubResponse {
            StubResponse(
                statusCode: 200,
                contentType: "application/json",
                data: Data(value.utf8)
            )
        }

        static func text(_ value: String) -> StubResponse {
            StubResponse(
                statusCode: 200,
                contentType: "text/plain; charset=utf-8",
                data: Data(value.utf8)
            )
        }
    }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> StubResponse)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let stub = try handler(request)
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": stub.contentType]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
