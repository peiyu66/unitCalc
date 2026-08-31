//
//  conv.swift
//  convCalculator
//
//  Created by peiyu on 2021/4/23.
//

import Foundation

@MainActor
final class Calculator: ObservableObject {
    private let defaults: UserDefaults
    private let session: URLSession
    private let significantDigits = 13
    let outputLength = 16

    private var didLoadCachedCurrency = false
    private var isRefreshingCurrency = false

    init(defaults: UserDefaults = .standard, session: URLSession? = nil) {
        self.defaults = defaults
        self.session = session ?? Self.makeDefaultSession()
        factors = currency + metric
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }

    func activate() async {
        if !didLoadCachedCurrency {
            loadCachedCurrencyRate()
            didLoadCachedCurrency = true
        }

        await refreshCurrencyRateIfNeeded()
    }
    
    //計算機
    
    @Published var valueMemory: Double?        //記憶的數字
    @Published var textCurrent = "0"           //組字中的運算元數字，或計算後的輸出數字
    @Published var textLastKey = ""            //前一個按鍵
    @Published var valueInput: Double?          //等待運算子的當前運算元的值
    @Published private(set) var calculationErrorDescription: String?
    var valueCurrent:Double = 0    //組字中的運算元的值，或計算後的值
    var valueOperant:Double = 0    //組字完成的「前」運算元，或計算後的值作為「前」運算元
    var textOperator:String = ""   //等待「後」運算元的運算子
    var opLog:[(vOperant:Double, tOperator:String, vInput:Double?, key:String,
                vCurrent:Double, tLastKey:String, vMemory:Double?, type:String)] = []

    let power10:[String:Double] = [
        "十萬":100000,
        "百萬":1000000,
        "千萬":10000000,
        "億":100000000,
        "十億":1000000000,
        "百億":10000000000,
        "千億":100000000000,
        "兆":1000000000000
        ]
    let opBasic:[String:String] = [
        "+":"+",
        "-":"−",
        "*":"×",
        "/":"÷"]
    let opStrong:[String] = ["∛","√","x²","x³"]
    let digits:String = ".0123456789"

    var hasHistory: Bool {
        !opLog.isEmpty
    }

    func isOperator(_ key: String) -> Bool {
        opBasic[key] != nil || key == "="
    }

    func isPowerOfTen(_ key: String) -> Bool {
        power10[key] != nil
    }

    func isKeyEnabled(_ key: String) -> Bool {
        if textCurrent.contains("."), valueInput != nil, key == "." {
            return false
        }
        if isPowerOfTen(textLastKey), isPowerOfTen(key) || digits.contains(key) {
            return false
        }
        if opBasic[textLastKey] != nil,
           opBasic[key] != nil || opStrong.contains(key) || key == "=" {
            return false
        }
        if valueMemory == nil, key == "mc" || key == "mr" {
            return false
        }
        if (outputText(valueCurrent).count >= outputLength || textCurrent.count >= significantDigits),
           valueInput != nil,
           digits.contains(key) {
            return false
        }
        return true
    }
    

    var isEditing:Bool {
        return valueCurrent == (valueInput ?? 0)
    }
    
    func keyin (_ key:String,byUser:Bool=false) {
        if calculationErrorDescription != nil {
            if digits.contains(key) {
                prepareForNewInputAfterError()
            } else if key != "C" {
                return
            }
        }

        switch key {
        case "0","1","2","3","4","5","6","7","8","9",".":
            if valueInput == nil || textCurrent == "0" { //忽略重複的整數零
                if key == "." {    //小數點前補零
                    textCurrent = "0."
                } else {
                    textCurrent = key
                }
            } else {
                textCurrent += key
            }
            valueCurrent = (Double(textCurrent.replacingOccurrences(of: ",", with: "")) ?? 0)
            valueInput = valueCurrent
            
        case "十萬","百萬","千萬","億","十億","百億","千億","兆":
            if let vCurrent = valueInput {
                valueInput = vCurrent * (power10[key] ?? 1)
            } else {
                valueInput = (power10[key] ?? 0)
            }
            valueCurrent = valueInput ?? 0
            textCurrent = outputText(valueCurrent)
            
        case "+","-","*","/","=":
            if key == "=" && (valueOperant == 0 && valueCurrent == 0 || valueOperant == valueCurrent) && (textOperator == "" || textOperator == "=")  && valueInput == nil {
                break
            }
            let vOperant = valueOperant
            switch textOperator {
            case "+":
                valueOperant += valueCurrent
            case "-":
                valueOperant -= valueCurrent
            case "*":
                valueOperant *= valueCurrent
            case "/":
                guard valueCurrent != 0 else {
                    showCalculationError("無法除以零")
                    return
                }
                valueOperant /= valueCurrent
            default:
                if let vc = valueInput {
                    valueOperant = vc
                } else {
                    valueOperant = valueCurrent
                }
            }
            valueCurrent = valueOperant
            textCurrent = outputText(valueCurrent)
            if opBasic[textOperator] != nil || isEditing || byUser {
                opLog.append((vOperant,(byUser ? textOperator : unitFrom),valueInput,key,
                              valueCurrent,textLastKey,valueMemory, (byUser ? "op" : "unit")))
            }
            valueInput = nil
            textOperator = key
            

        case "x²","√","∛","x³":
            switch key {
            case "x³":
                valueInput = pow(valueCurrent,3)
            case "x²":
                valueInput = pow(valueCurrent,2)
            case "√":
                guard valueCurrent >= 0 else {
                    showCalculationError("負數沒有實數平方根")
                    return
                }
                valueInput = sqrt(valueCurrent)
            case "∛":
                valueInput = cbrt(valueCurrent)
            default:
                break
            }
            guard valueInput?.isFinite == true else {
                showCalculationError("計算結果超出可表示範圍")
                return
            }
            opLog.append((valueOperant,textOperator,valueInput,key,
                          valueCurrent,textLastKey,valueMemory, "op"))
            valueCurrent = valueInput ?? 0
            textCurrent = outputText(valueCurrent)
        case "ms","mc","mr":
            switch key {
            case "ms":
                valueMemory = valueInput ?? valueCurrent
            case "mc":
                valueMemory = nil
            case "mr":
                valueInput = valueMemory
                valueCurrent = valueInput ?? 0
                textCurrent = outputText(valueCurrent)
            default:
                break
            }
            
        case "CE":
            if let lastLog = opLog.last {
                if isEditing && !opStrong.contains(lastLog.key) {
                    if byUser {
                        valueCurrent = valueOperant
                        textCurrent = outputText(valueCurrent)
                        valueInput = nil
                        textLastKey = textOperator
                    } else {
                        opLog.append((valueOperant,textOperator,valueInput,unitFrom,
                                      valueCurrent,textLastKey,valueMemory,"op"))
                    }
                } else if lastLog.type == "op" {
                    valueCurrent = (opStrong.contains(lastLog.key) ? lastLog.vCurrent : (lastLog.vInput ?? 0))
                    textCurrent = outputText(valueCurrent)
                    valueOperant = lastLog.vOperant
                    textOperator = lastLog.tOperator
                    valueInput = (opStrong.contains(lastLog.key) ? lastLog.vCurrent : lastLog.vInput)
                    textLastKey = lastLog.tLastKey
                    opLog.removeLast()
                    
                    //                if byUser {
                    //                    //更進一步回復到前運算子之後
                    //                    valueCurrent = valueOperant
                    //                    if opStrong.contains(lastLog.key) {
                    //                        textCurrent = outputText(lastLog.vOperant)
                    //                    } else {
                    //                        textCurrent = outputText(valueCurrent)
                    //                    }
                    //                    valueInput = nil
                    //                    textLastKey = lastLog.tOperator
                    //                }
                }
            } else if byUser {
                valueInput = nil
                valueOperant = 0
                textOperator = ""
                valueCurrent = 0
                textCurrent = "0"
                textLastKey = ""
            }
        case "C":
            calculationErrorDescription = nil
            valueInput = nil
            valueOperant = 0
            textOperator = ""
            textCurrent = "0"
            valueCurrent = 0
            if textLastKey == "C" {
                valueMemory = nil
                opLog = []
                textLastKey = ""
                logCurrencyTime = nil
            }
            while let last = opLog.last, last.key != "=" && last.type == "op" {
                opLog.removeLast()
            }

        default:
            break
        }
        
        if key != "CE" {
            textLastKey = key
        }
        
    }
    
    func outputText(_ value:Double) -> String {
        guard value.isFinite else { return "錯誤" }

        let eOutput = String(format:"%.\(significantDigits)g",value)
        if eOutput.contains("e") {
            return eOutput
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.locale = Locale(identifier: "en_US_POSIX")
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = significantDigits
            numberFormatter.usesGroupingSeparator = true
            numberFormatter.groupingSeparator = ","
            numberFormatter.groupingSize = 3
            let nOutput = numberFormatter.string(for: value) ?? "[error]"
            return nOutput
        }
    }

    private func showCalculationError(_ message: String) {
        calculationErrorDescription = message
        textCurrent = "錯誤"
        valueInput = nil
        valueCurrent = 0
        valueOperant = 0
        textOperator = ""
        textLastKey = "error"
        opLog = []
    }

    private func prepareForNewInputAfterError() {
        calculationErrorDescription = nil
        textCurrent = "0"
        valueInput = nil
        valueCurrent = 0
        valueOperant = 0
        textOperator = ""
        textLastKey = ""
        opLog = []
    }

    var logText:String {
        func tOutput(_ value:Double) -> String {
            let txtOutput = outputText(value)
            if txtOutput.contains("e") {
                return "(\(txtOutput))"
            } else {
                return txtOutput
            }
        }
        
        var text = ""
        var semiComma:Bool = false
        var converted:Bool = false
        
        for log in opLog {
            var tCurrent:String
            if opStrong.contains(log.key) {
                tCurrent = tOutput(log.vCurrent)
            } else {
                tCurrent = tOutput(log.vInput ?? log.vCurrent)
            }

            switch log.type {
            case "cat":
                if semiComma {
                    text += "; "
                }
                text += "\(log.tOperator)→\(log.key)"
                converted = (log.vCurrent != 0 ? false : true)
                semiComma = true
            
            case "unit":
                
                if log.key == "=" {
                    if log.vCurrent != 0 {
                        text += (semiComma ? "; " : "") + "\(tCurrent)\(log.tOperator)"
                        semiComma = true
                    }
                } else if converted {
                    text += "=\(tCurrent)\(log.key)"
                } else {
                    text += "; \(tOutput(log.vOperant))\(log.tOperator)=\(tCurrent)\(log.key)"
                }
                converted = true

            case "op":
                converted = false
                if semiComma {
                    text += "; "
                }
                if opStrong.contains(log.key) {
                    text += "\(log.key)[\(tCurrent)]"
                } else {
                    text +=  tCurrent + (opBasic[log.key] ?? log.key)
                }
                if log.key == "=" {
                    let vCurrent = outputText(log.vCurrent)
                    text += (vCurrent.contains("e") ? "(" : "") + vCurrent + (vCurrent.contains("e") ? ")" : "")
                    semiComma = true
                } else {
                    semiComma = false
                }
                
            default:
                break
            }

        }
        
        return text
    }
    

    //單位換算
    
    let units:[String:[String]] =  [
        "貨幣":["台幣","美元","日圓","歐元","英鎊","韓元","越南盾","港幣","人民幣"],
        "重量":["公克","公斤","台斤","台兩","英磅","盎司"],
        "長度":["公尺","公分","台尺","台寸","英尺","英寸"],
        "面積":["台坪","台畝","台分","台甲","m²","公頃","ft²"],
        ]
    
    let categories = ["貨幣", "重量", "長度", "面積"]
    
    var unitList:[String] {
        var list:[String] = []
        for (_, value) in units {
            list += value
        }
        return list
    }
    
    
    var cat:String = "-"
    var catFrom:String = "-"
    var unit:String = "-"
    var unitFrom:String = "-"
    var catIndex:Int = 0
    var catFromIndex:Int = 0
    var unitIndex:Int = 0
    var unitFromIndex:Int = 0
    var logCurrencyTime:Date?

    func unitConvert(pickerCat:String, pickerUnit:String) {
        if let u = units[pickerCat], u.contains(pickerUnit) && pickerUnit != unit {
            catFrom = cat
            cat = pickerCat
            unitFrom = unit
            unit = pickerUnit
            
            if let i = categories.firstIndex(of: catFrom) {
                catFromIndex = i
            }
            if let i = categories.firstIndex(of: cat) {
                catIndex = i
            }
            if let u = units[catFrom], let i = u.firstIndex(of: unitFrom) {
                unitFromIndex = i
            }
            if let u = units[cat], let i = u.firstIndex(of: unit) {
                unitIndex = i
            }

            if unitFrom != "-" {
                if !isEditing {
                    textOperator = ""
                }
                keyin("=")
                if cat == catFrom {
                    if valueCurrent != 0  {
                        let factor0=factors[catIndex][unitFromIndex][unitIndex].f0
                        let factor1=factors[catIndex][unitFromIndex][unitIndex].f1
                        textOperator = unitFrom
                        valueInput = (valueCurrent * factor0 / factor1)
                        opLog.append((valueOperant,unitFrom,valueInput,unit,
                                      valueCurrent,textLastKey,valueMemory,"unit"))
                        valueCurrent = valueInput ?? 0
                        textCurrent = outputText(valueCurrent)
                        textOperator = ""
                    }
                } else {
                    textOperator = catFrom
                    var k:String = cat
                    if let t = currencyTime, cat == "貨幣", t != logCurrencyTime  {
                        func formatter(_ format:String="yyyy/MM/dd") -> DateFormatter  {
                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: "zh_Hant_TW")
                            formatter.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
                            formatter.dateFormat = format
                            return formatter
                        }
                        let dt = formatter("M月d日H時m分").string(from: t)
                        k = "\(cat)·\(currencySource)(\(dt))"
                        logCurrencyTime = t
                    }
                    opLog.append((valueOperant,catFrom,valueInput,k,
                                  valueCurrent,textLastKey,valueMemory,"cat"))
                    textOperator = unit
                }
                valueInput = nil
            }
        }
        
    }

    @Published private(set) var currencySource = "台灣銀行" // BOT, Bank of Taiwan
    private let currencyCode = ["TWD", "USD", "JPY", "EUR", "GBP", "KRW", "VND", "HKD", "CNY"]
    @Published private(set) var currencyTime: Date? // 最後成功取得全部匯率的時間
    @Published private(set) var currencyErrorDescription: String?

    //轉換係數：為了精度所以使用雙係數。例如3公斤=5台斤，則2公斤=2*5/3台斤。
    //這是3維陣列：[度量種類][原單位][新單位]
    struct p: Codable { //factor pairs
        var f0:Double
        var f1:Double
    }
    var factors:[[[p]]] = []
    var currency:[[[p]]] = [[
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)],
            [p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0),p(f0:1.0,f1:1.0)]
        ]]
    let metric:[[[p]]] = [
        [ //重量
            // 公克                    公斤                         台斤                        台兩                        磅                       盎司
            [p(f0:1.0,      f1:1.0),  p(f0:1.0,       f1:1000.0), p(f0:5.0,       f1:3000.0), p(f0:8.0,       f1:300.0), p(f0:1.0,f1:453.59237),  p(f0:16.0,f1:453.59237)],  // 公克 3000公克=5台斤=80台兩
            [p(f0:1000.0,   f1:1.0),  p(f0:1.0,       f1:1.0),    p(f0:5.0,       f1:3.0),    p(f0:80.0,      f1:3.0),   p(f0:1.0,f1:0.45359237), p(f0:16.0,f1:0.45359237)], // 公斤 3公斤=5台斤
            [p(f0:3000.0,   f1:5.0),  p(f0:3.0,       f1:5.0),    p(f0:1.0,       f1:1.0),    p(f0:16.0,      f1:1.0),   p(f0:3.0,f1:2.26796185), p(f0:48.0,f1:2.26796185)], // 台斤 1台斤=16台兩=(3/2.26796185)磅
            [p(f0:300.0,    f1:8.0),  p(f0:3.0,       f1:80.0),   p(f0:1.0,       f1:16.0),   p(f0:1.0,       f1:1.0),   p(f0:3.0,f1:36.2873896), p(f0:48.0,f1:36.2873896)], // 台兩 1台兩=(3/2.26796185*16)磅=(3/36.2873896)磅
            [p(f0:453.59237,f1:1.0),  p(f0:0.45359237,f1:1.0),    p(f0:2.26796185,f1:3.0),    p(f0:36.2873896,f1:3.0),   p(f0:1.0,f1:1.0),        p(f0:16.0,f1:1.0)],        // 磅 1磅=453.59237公克=16盎司=(453.59237*5)/3000台斤=(2.26796185/3)台斤
            [p(f0:453.59237,f1:16.0), p(f0:0.45359237,f1:16.0),   p(f0:2.26796185,f1:48.0),   p(f0:36.2873896,f1:48.0),  p(f0:1.0,f1:16.0),       p(f0:1.0, f1:1.0)]          // 盎司
        ] ,
        [ //長度
            // 公尺                 公分                   台尺                    台寸                      英呎                     英吋
            [p(f0:1.0,  f1:1.0),   p(f0:100.0, f1:1.0),  p(f0:33.0,   f1:10.0),  p(f0:330.0,  f1:10.0),   p(f0:100.0,f1:30.48),   p(f0:100.0,f1:2.54)],    // 公尺 10公尺=33台尺
            [p(f0:1.0,  f1:100.0), p(f0:1.0,   f1:1.0),  p(f0:33.0,   f1:1000.0),p(f0:330.0,  f1:1000.0), p(f0:1.0,  f1:30.48),   p(f0:1.0,  f1:2.54)],    // 公分
            [p(f0:10.0, f1:33.0),  p(f0:1000.0,f1:33.0), p(f0:1.0,    f1:1.0),   p(f0:10.0,   f1:1.0),    p(f0:1.0,  f1:1.00584), p(f0:12.0, f1:1.00584)], // 台尺 1005.84台尺=1000英呎=304.8公尺=304.8*3.3台尺
            [p(f0:10.0, f1:330.0), p(f0:1000.0,f1:330.0),p(f0:1.0,    f1:10.0),  p(f0:1.0,    f1:1.0),    p(f0:1.0,  f1:10.0584), p(f0:12.0, f1:10.0584)], // 台寸 1台尺=10台寸
            [p(f0:30.48,f1:100.0), p(f0:30.48, f1:1.0),  p(f0:1.00584,f1:1.0),   p(f0:10.0584,f1:1.0),    p(f0:1.0,  f1:1.0),     p(f0:12.0, f1:1.0)],     // 英呎 1英呎=30.48公分=12英吋
            [p(f0:2.54, f1:100.0), p(f0:2.54,  f1:1.0),  p(f0:1.00584,f1:12.0),  p(f0:10.0584,f1:12.0),   p(f0:1.0,  f1:12.0),   p (f0:1.0,  f1:1.0)]      // 英吋
        ],
        [ //面積
            // 坪                      畝                       分                         甲                           平方公尺                 公頃                       平方英尺
            [p(f0:1.0,      f1:1.0),  p(f0:1.0,      f1:30.0), p(f0:1.0,       f1:293.4), p(f0:1.0,       f1:2934.0), p(f0:400.0,   f1:121.0),p(f0:0.04,    f1:121.0),  p(f0:400.0,   f1:11.241268)],  //坪 11.241268坪=400平方英尺
            [p(f0:30.0,     f1:1.0),  p(f0:1.0,      f1:1.0),  p(f0:1.0,       f1:9.78),  p(f0:1.0,       f1:97.8),   p(f0:12000.0, f1:121.0),p(f0:1.2,     f1:121.0),  p(f0:12000,   f1:11.241268)],  //畝 1畝=30坪=(30*400/11.241268)平方英尺, 121畝=12000平方公尺=1.2公頃
            [p(f0:293.4,    f1:1.0),  p(f0:9.78,     f1:1.0),  p(f0:1.0,       f1:1.0),   p(f0:1.0,       f1:10.0),   p(f0:117360,  f1:121),  p(f0:11.736,  f1:121),    p(f0:117360.0,f1:11.2412678)], //分 1分=9.78畝, 112412.678畝=(12000*9.78)平方英尺=117360平方英尺
            [p(f0:2934,     f1:1.0),  p(f0:97.8,     f1:1.0),  p(f0:10.0,      f1:1.0),   p(f0:1.0,       f1:1.0),    p(f0:1173600, f1:121),  p(f0:117.36,  f1:121),    p(f0:117360.0,f1:1.12412678)], //甲 1甲=10分=97.8畝,(121/97.8)甲=1.2頃,121甲=117.36頃
            [p(f0:121.0,    f1:400),  p(f0:121.0,    f1:12000),p(f0:121,       f1:117360),p(f0:121,       f1:1173600),p(f0:1.0,     f1:1.0),  p(f0:1.0,     f1:10000),  p(f0:100.0,   f1:9.290304)],   //平方公尺 400平方公尺=121坪
            [p(f0:121.0,    f1:0.04), p(f0:121.0,    f1:1.2),  p(f0:121,       f1:11.736),p(f0:121,       f1:117.36), p(f0:10000,   f1:1.0),  p(f0:1.0,     f1:1.0),    p(f0:1000000, f1:9.290304)],   //公頃 10000平方公尺=1頃,1000000平方英尺=92903.04平方公尺=9.290304公頃
            [p(f0:11.241268,f1:400.0),p(f0:11.241268,f1:12000),p(f0:11.2412678,f1:117360),p(f0:1.12412678,f1:117360), p(f0:9.290304,f1:100),  p(f0:9.290304,f1:1000000),p(f0:1.0,     f1:1.0)]         //平方英尺 100平方英尺=9.290304平方公尺
        ]
    ]

    private func loadCachedCurrencyRate() {
        guard
            let savedTime = defaults.object(forKey: "currencyTime") as? Date,
            let data = defaults.data(forKey: "currencyRate"),
            let savedCurrency = try? JSONDecoder().decode([[[p]]].self, from: data),
            isValidCurrencyMatrix(savedCurrency)
        else {
            factors = currency + metric
            return
        }

        currencyTime = savedTime
        currencySource = defaults.string(forKey: "currencySource") ?? "台灣銀行"
        currency = savedCurrency
        factors = currency + metric
    }

    private func refreshCurrencyRateIfNeeded() async {
        guard !isRefreshingCurrency else { return }
        if let currencyTime, currencyTime.timeIntervalSinceNow > -14_400 {
            return // 上次成功查詢匯率還沒超過四小時
        }

        isRefreshingCurrency = true
        defer { isRefreshingCurrency = false }

        do {
            let update: CurrencyUpdate
            do {
                update = try await fetchBankOfTaiwanUpdate()
            } catch let bankError {
                do {
                    update = try await fetchCentralBankUpdate()
                } catch let centralBankError {
                    throw CurrencyRateError.allSourcesFailed(
                        bank: bankError.localizedDescription,
                        centralBank: centralBankError.localizedDescription
                    )
                }
            }

            currency = update.matrix
            currencyTime = update.timestamp
            currencySource = update.source
            currencyErrorDescription = nil
            factors = currency + metric
            saveCurrencyRate()
        } catch {
            // 保留最後一次成功的資料；網站暫時失效不應破壞離線換算。
            currencyErrorDescription = error.localizedDescription
        }
    }

    private func fetchBankOfTaiwanUpdate() async throws -> CurrencyUpdate {
        let timestampPage = try await fetchText(
            from: URL(string: "https://rate.bot.com.tw/xrt?Lang=zh-TW")
        )
        let ratePage = try await fetchText(
            from: URL(string: "https://rate.bot.com.tw/xrt/fltxt/0/day")
        )
        return CurrencyUpdate(
            matrix: try makeCurrencyMatrix(from: ratePage),
            timestamp: try parseBOTTimestamp(timestampPage),
            source: "台灣銀行"
        )
    }

    private func fetchCentralBankUpdate() async throws -> CurrencyUpdate {
        let data = try await fetchData(
            from: URL(string: "https://cpx.cbc.gov.tw/API/DataAPI/Get?FileName=BP01D01")
        )
        let response = try JSONDecoder().decode(CentralBankResponse.self, from: data)
        guard let latest = response.data.dataSets.last, latest.indices.contains(18) else {
            throw CurrencyRateError.invalidCentralBankData
        }

        func number(at index: Int) throws -> Double {
            guard let value = Double(latest[index]), value > 0 else {
                throw CurrencyRateError.invalidCentralBankData
            }
            return value
        }

        let twdPerUSD = try number(at: 1)
        let twdValues = try [
            1,
            twdPerUSD,
            twdPerUSD / number(at: 2),  // JPY per USD
            twdPerUSD * number(at: 14), // USD per EUR
            twdPerUSD * number(at: 3),  // USD per GBP
            twdPerUSD / number(at: 5),  // KRW per USD
            twdPerUSD / number(at: 18), // VND per USD
            twdPerUSD / number(at: 4),  // HKD per USD
            twdPerUSD / number(at: 8)   // CNY per USD
        ]
        let matrix = twdValues.map { sourceValue in
            twdValues.map { destinationValue in
                p(f0: sourceValue, f1: destinationValue)
            }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyyMMdd HH:mm"
        guard let timestamp = formatter.date(from: "\(latest[0]) 16:00") else {
            throw CurrencyRateError.invalidCentralBankData
        }

        return CurrencyUpdate(
            matrix: [matrix],
            timestamp: timestamp,
            source: "央行參考"
        )
    }

    private func fetchData(from url: URL?) async throws -> Data {
        guard let url else { throw CurrencyRateError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(
            "unitCalc/1.1 (tw.com.unlock.unitCalc)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            200..<300 ~= httpResponse.statusCode
        else {
            throw CurrencyRateError.invalidResponse
        }
        guard data.count <= 5_000_000 else {
            throw CurrencyRateError.responseTooLarge
        }
        return data
    }

    private func fetchText(from url: URL?) async throws -> String {
        let data = try await fetchData(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CurrencyRateError.invalidText
        }
        return text
    }

    private func parseBOTTimestamp(_ data: String) throws -> Date {
        let leading = "最新掛牌時間：<span class=\"time\">"
        let trailing = "</span>"
        guard let range = data.range(
            of: "\(leading)(.+?)\(trailing)",
            options: .regularExpression
        ) else {
            throw CurrencyRateError.timestampNotFound
        }

        let startIndex = data.index(range.lowerBound, offsetBy: leading.count)
        let endIndex = data.index(range.upperBound, offsetBy: -trailing.count)
        let timestampText = String(data[startIndex..<endIndex])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"

        guard let timestamp = formatter.date(from: timestampText) else {
            throw CurrencyRateError.timestampNotFound
        }
        return timestamp
    }

    func makeCurrencyMatrix(from data: String) throws -> [[[p]]] {
        var taiwanDollarValues = [1.0]
        for code in currencyCode.dropFirst() {
            guard let quote = parseBOTQuote(data, code: code), quote.cashSelling > 0 else {
                throw CurrencyRateError.rateNotFound(code)
            }
            taiwanDollarValues.append(quote.cashSelling)
        }

        let matrix = taiwanDollarValues.map { sourceValue in
            taiwanDollarValues.map { destinationValue in
                p(f0: sourceValue, f1: destinationValue)
            }
        }
        return [matrix]
    }

    func parseBOTQuote(
        _ data: String,
        code: String
    ) -> (cashBuying: Double, cashSelling: Double, spotBuying: Double, spotSelling: Double)? {
        guard let line = data.split(whereSeparator: \.isNewline).first(where: { line in
            line.split(whereSeparator: \.isWhitespace).first.map(String.init) == code
        }) else {
            return nil
        }

        let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard
            let buyingIndex = fields.firstIndex(where: { $0 == "Buying" || $0 == "本行買入" }),
            let sellingIndex = fields.firstIndex(where: { $0 == "Selling" || $0 == "本行賣出" }),
            fields.indices.contains(buyingIndex + 2),
            fields.indices.contains(sellingIndex + 2)
        else { return nil }

        var cashBuying = Double(fields[buyingIndex + 1]) ?? 0
        var spotBuying = Double(fields[buyingIndex + 2]) ?? 0
        var cashSelling = Double(fields[sellingIndex + 1]) ?? 0
        var spotSelling = Double(fields[sellingIndex + 2]) ?? 0

        if cashSelling == 0 { cashSelling = spotSelling }
        if spotSelling == 0 { spotSelling = cashSelling }
        if cashBuying == 0 { cashBuying = spotBuying }
        if spotBuying == 0 { spotBuying = cashBuying }

        guard cashSelling > 0 else { return nil }
        return (cashBuying, cashSelling, spotBuying, spotSelling)
    }

    private func saveCurrencyRate() {
        guard let currencyTime, let data = try? JSONEncoder().encode(currency) else { return }
        defaults.set(currencyTime, forKey: "currencyTime")
        defaults.set(currencySource, forKey: "currencySource")
        defaults.set(data, forKey: "currencyRate")
    }

    func isValidCurrencyMatrix(_ matrix: [[[p]]]) -> Bool {
        guard
            matrix.count == 1,
            matrix[0].count == currencyCode.count,
            matrix[0].allSatisfy({ $0.count == currencyCode.count })
        else { return false }

        let rates = matrix[0].map { row in
            row.map { factor in factor.f0 / factor.f1 }
        }
        guard rates.joined().allSatisfy({ $0.isFinite && $0 > 0 }) else { return false }

        for index in rates.indices {
            guard abs(rates[index][index] - 1) < 1e-12 else { return false }
            for destination in rates.indices {
                let roundTrip = rates[index][destination] * rates[destination][index]
                guard abs(roundTrip - 1) < 1e-9 else { return false }
            }
        }
        return true
    }

    private struct CurrencyUpdate {
        let matrix: [[[p]]]
        let timestamp: Date
        let source: String
    }

    private struct CentralBankResponse: Decodable {
        let data: CentralBankData
    }

    private struct CentralBankData: Decodable {
        let dataSets: [[String]]
    }

    private enum CurrencyRateError: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidText
        case timestampNotFound
        case rateNotFound(String)
        case invalidCentralBankData
        case responseTooLarge
        case allSourcesFailed(bank: String, centralBank: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                "匯率網址無效"
            case .invalidResponse:
                "台灣銀行暫時無法回應"
            case .invalidText:
                "台灣銀行回傳的資料無法讀取"
            case .timestampNotFound:
                "找不到台灣銀行掛牌時間"
            case .rateNotFound(let code):
                "找不到 \(code) 匯率"
            case .invalidCentralBankData:
                "中央銀行匯率資料格式不完整"
            case .responseTooLarge:
                "匯率資料大小異常"
            case .allSourcesFailed(let bank, let centralBank):
                "匯率更新失敗（臺灣銀行：\(bank)；中央銀行：\(centralBank)）"
            }
        }
    }
}
