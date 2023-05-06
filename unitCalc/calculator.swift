//
//  conv.swift
//  convCalculator
//
//  Created by peiyu on 2021/4/23.
//

import Foundation
import SwiftUI

class calculator:ObservableObject {
    let defaults = UserDefaults.standard

    @Published var widthClass:WidthClass = .compact
    
    var versionNow:String
    var versionLast:String = ""

    private let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    private let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String

    enum WidthClass {
        case compact
        case regularPhone
        case regularPad
        case widePad
        case widePhone
    }
    
    func cgByClass (_ cg:[CGFloat]) -> CGFloat { //[widePhone,widePad,regularPad,regularPhone,compact]
        switch widthClass {
        case .widePhone:
                return cg[0]
        case .widePad:
            if let last = cg.last, cg.count < 2 {
                return last
            } else {
                return cg[1]
            }
        case .regularPad:
            if let last = cg.last, cg.count < 3 {
                return last
            } else {
                return cg[2]
            }
        case .regularPhone:
            if let last = cg.last, cg.count < 4 {
                return last
            } else {
                return cg[3]
            }
        default: // .compact
            if let last = cg.last, cg.count < 5 {
                return last
            } else {
                return cg[4]
            }
        }
    }
    
    var sigfig:Int {
        return Int(cgByClass([13,13,11,9]))
    }
    
    var outputLength:Int {
        return Int(cgByClass([16,16,14,11]))
    }
    
    private var hClass = UITraitCollection.current.horizontalSizeClass
    private var isPad  = UIDevice.current.userInterfaceIdiom == .pad

    var deviceWidthClass: WidthClass {
        var wClass:WidthClass
        if UIDevice.current.orientation.isLandscape {
            if isPad {
                wClass = .widePad
            } else {
                wClass = .widePhone
            }
        } else if UIDevice.current.orientation.isPortrait {
            if isPad {
                wClass = .regularPad
            } else if hClass == .regular {
                wClass = .regularPhone
            } else {
                wClass = .compact
            }
        } else {
            wClass = widthClass
        }
        NSLog("widthClass:\(wClass)")
        return wClass
    }
    
    init() {
        versionNow = versionNo + (buildNo == "0" ? "" : "(\(buildNo))")
        widthClass = deviceWidthClass
        NotificationCenter.default.addObserver(self, selector: #selector(self.setWidthClass), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func setWidthClass(_ notification: Notification) {
        widthClass = deviceWidthClass
        if valueInput == nil {
            textCurrent = outputText(valueCurrent)
        }
    }
    

    @objc private func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            NSLog ("=== appDidBecomeActive v\(versionNow) ===")
            self.versionLast = UserDefaults.standard.string(forKey: "simStockVersion") ?? ""
            UserDefaults.standard.set(versionNow, forKey: "simStockVersion")
            if versionLast != versionNow {
                defaults.removeObject(forKey: "currencyTime")
                defaults.removeObject(forKey: "currencyRate")
                NSLog("version: \(versionLast) → \(versionNow)")
            }
            widthClass = deviceWidthClass
            loadCurrencyRate()
            
        case UIApplication.willResignActiveNotification:
            NSLog ("=== appWillResignActive ===")
        default:
            break
        }

    }
    
    //計算機
    
    @Published var valueMemory:Double?        //記憶的數字
    @Published var textCurrent:String = "0"   //組字中的運算元數字，或計算後的輸出數字
    @Published var textLastKey:String = ""    //前一個按鍵
    @Published var valueInput:Double?         //等待運算子的當前運算元的值
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
    

    var isEditing:Bool {
        return valueCurrent == (valueInput ?? 0)
    }
    
    func keyin (_ key:String,byUser:Bool=false) {
                
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
            print(opLog.last.debugDescription)
            print(">> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(key),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))\n")

            valueInput = nil
            textOperator = key
            

        case "x²","√","∛","x³":
            switch key {
            case "x³":
                valueInput = pow(valueCurrent,3)
            case "x²":
                valueInput = pow(valueCurrent,2)
            case "√":
                valueInput = sqrt(valueCurrent)
            case "∛":
                valueInput = cbrt(valueCurrent)
            default:
                break
            }
            opLog.append((valueOperant,textOperator,valueInput,key,
                          valueCurrent,textLastKey,valueMemory, "op"))
            valueCurrent = valueInput ?? 0
            textCurrent = outputText(valueCurrent)
            print(opLog.last.debugDescription)
            print(">> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(key),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))\n")
            
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
                    print("isEditing >> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(key),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))")
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
            print(">> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(key),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))\n")

            
        case "C":
            valueInput = nil
            valueOperant = 0
            textOperator = ""
            textCurrent = "0"
            valueCurrent = 0
            if textLastKey == "C" {
                valueMemory = nil
                opLog = []
                textLastKey = ""
                UIPasteboard.general.string = nil
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

        //let roundScale:Double = pow(Double(10),Double(decimal))
        //let roundedValue:Double = round(value * roundScale) / roundScale)
        
        let eOutput = String(format:"%.\(sigfig)g",value)
        if eOutput.contains("e") {
            return eOutput
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = 4
            numberFormatter.usesGroupingSeparator = true
            numberFormatter.groupingSeparator = ","
            numberFormatter.groupingSize = 3
            let nOutput = numberFormatter.string(for: value) ?? "[error]"
            return nOutput
        }
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
        
        let leading:Int = Int(cgByClass([150,100,60]))
        if text.count < leading { //讓自動捲動不會因為字數少不用捲而停擺
            text = repeatElement(" ", count: leading - text.count ) + text
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
    
    var cats:[String] {
        return Array(units.keys).sorted()
    }
    
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
            
            if let i = cats.firstIndex(of: catFrom) {
                catFromIndex = i
            }
            if let i = cats.firstIndex(of: cat) {
                catIndex = i
            }
            if let u = units[catFrom], let i = u.firstIndex(of: unitFrom) {
                unitFromIndex = i
            }
            if let u = units[cat], let i = u.firstIndex(of: unit) {
                unitIndex = i
            }

            if unitFrom != "-" {
                print(catFrom,unitFrom,"-->",cat,unit)
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
                        print(opLog.last.debugDescription)
                        print(">> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(unit),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))\n")
                    }
                } else {
                    textOperator = catFrom
                    var k:String = cat
                    if let t = currencyTime, cat == "貨幣", t != logCurrencyTime  {
                        func formatter(_ format:String="yyyy/MM/dd") -> DateFormatter  {
                            let formatter = DateFormatter()
                            formatter.locale = Locale(identifier: "zh_Hant_TW")
                            formatter.timeZone = TimeZone(identifier: "Asia/Taipei")!
                            formatter.dateFormat = format
                            return formatter
                        }
                        let dt = formatter("M月d日H時m分").string(from: t)
                        k = "\(cat)(\(dt))"
                        logCurrencyTime = t
                    }
                    opLog.append((valueOperant,catFrom,valueInput,k,
                                  valueCurrent,textLastKey,valueMemory,"cat"))
                    textOperator = unit
                    print(opLog.last.debugDescription)
                    print(">> vOperant=\(valueOperant), op: \(textOperator), vInput: \(String(describing: valueInput)), key: \(unit),  vcurrent=\(valueCurrent), last: \(textLastKey), m=\(String(describing: valueMemory))\n")
                }
                valueInput = nil
            }
        }
        
    }

    var currencySource:String = "台灣銀行" //BOT, Bank of Taiwan
    let currencyCode:([String]) = ["TWD","USD","JPY","EUR","GBP","KRW","VND","HKD","CNY"]
    var currencyTime:Date?  //最後成功取得全部匯率的時間

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

    
    func loadCurrencyRate() {
        if let dt = defaults.object(forKey: "currencyTime") {
            currencyTime    = dt as? Date
            currencySource  = defaults.string(forKey: "currencySource") ?? ""
            
            if let data = defaults.object(forKey: "currencyRate")  {
                do {
                    let decoder = JSONDecoder()
                    currency = try decoder.decode([[[p]]].self, from:data as! Data)
                } catch {
                    NSLog("\ndecoder failed.")
                }
            }
        }
        factors = currency + metric
        if let dt = currencyTime, dt.timeIntervalSinceNow > -14400 {
            return //上次查詢匯率還沒超過4小時
        }
        queryBot()  //還沒成功查過就重試查詢匯率
    }
    

    

    func saveCurrencyRate() {
        if let dt = currencyTime {
            defaults.set(dt, forKey: "currencyTime")
            defaults.set(currencySource,forKey:"currencySource")
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(currency)
                defaults.set(data, forKey: "currencyRate")
            } catch {
                NSLog("\nencoder failed.")
            }
            factors = currency + metric
        }
    }

    //查詢台灣銀行匯率
    func queryBot () {
        let url = URL(string: "https://rate.bot.com.tw/xrt?Lang=zh-TW");
        var request = URLRequest(url: url!,timeoutInterval: 30)
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/605.1.12 (KHTML, like Gecko) Version/11.1 Safari/605.1.12"
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            if error == nil {
                if let downloadedData = String(data: data!, encoding: String.Encoding.utf8) {
                    let leading = "最新掛牌時間：<span class=\"time\">"
                    let trailing = "</span>"
                    if let range = downloadedData.range(of: "\(leading)(.+)\(trailing)", options: .regularExpression) {
                        let startIndex = downloadedData.index(range.lowerBound, offsetBy: leading.count)
                        let endIndex   = downloadedData.index(range.upperBound, offsetBy: 0-trailing.count)
                        let dTime = String(downloadedData[startIndex..<endIndex])
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale=Locale(identifier: "zh_TW")
                        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm zzz"
                        if let dt = dateFormatter.date(from: dTime+" GMT+8") {
                            self.currencyTime = dt
                            self.requestBotCurrency ()
                        }

                    }
                }
            }
        })
        task.resume()
    }


    func requestBotCurrency () {
        let url = URL(string: "https://rate.bot.com.tw/xrt/fltxt/0/day");
        var request = URLRequest(url: url!,timeoutInterval: 30)
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/605.1.12 (KHTML, like Gecko) Version/11.1 Safari/605.1.12"
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            if error == nil {
                if let downloadedData = String(data: data!, encoding: String.Encoding.utf8) {
                    for (indexFrom,_) in self.currencyCode.enumerated() {
                        for (indexTo,currencyTo) in self.currencyCode.enumerated() {
                            if indexFrom < indexTo {    //只查一半的表格，另一半就是係數顛倒，所以直接填入
                                if indexFrom == 0 {
                                    self.currency[0][indexFrom][indexTo].f1 = self.parsingBot(downloadedData,code: currencyTo).cashSelling
                                    self.currency[0][indexTo][indexFrom].f0 = self.currency[0][indexFrom][indexTo].f1
                                } else {
                                    self.currency[0][indexFrom][indexTo].f1 = self.currency[0][0][indexTo].f1   //以下皆以對台幣的價格帶入，以維持換算係數的一致
                                    self.currency[0][indexFrom][indexTo].f0 = self.currency[0][0][indexFrom].f1
                                    self.currency[0][indexTo][indexFrom].f1 = self.currency[0][0][indexFrom].f1
                                    self.currency[0][indexTo][indexFrom].f0 = self.currency[0][0][indexTo].f1
                               }
                            }

                        }
                    }
                    self.saveCurrencyRate()
                }
            } else {
                print("rate.bot.com.tw error!")
            }
        })
        task.resume()

    }

    func parsingBot (_ data:String,code:String) -> (cashBuying:Double,cashSelling:Double,spotBuying:Double,spotSelling:Double) {
        var cashBuying:Double   = 0
        var cashSelling:Double  = 0
        var spotBuying:Double   = 0
        var spotSelling:Double  = 0
        var buying:String  = "本行買入"
        var selling:String = "本行賣出"
        if data.contains("Currency") {
            buying  = "Buying"
            selling = "Selling"
        }
        let leading = "\(code)         \(buying)"
        let trailing = "\r"
        if let range=data.range(of: "\(leading)(.+)\(trailing)", options: .regularExpression) {
            let startIndex = data.index(range.lowerBound, offsetBy: leading.count)
            let endIndex = data.index(range.upperBound, offsetBy: 0-trailing.count)
            let data1 = String(data[startIndex..<endIndex])    //data.substring(with: range).replacingOccurrences(of: currency+"         \(buying)", with: "")
//            let data2 = data1.replacingOccurrences(of: "\r", with: "")
            let data3 = data1.replacingOccurrences(of: selling, with: "")
            let data4 = data3.replacingOccurrences(of: "    ", with: " ")
            let data5 = data4.replacingOccurrences(of: "  ", with: " ")
            let data6 = data5.replacingOccurrences(of: "  ", with: " ")
            let data0 = data6.replacingOccurrences(of: "  ", with: " ")
            if let d1=Double(data0.components(separatedBy: " ")[1]) {
                cashBuying  = d1    //買入現金
            }
            if let d2=Double(data0.components(separatedBy: " ")[10]) {
                cashSelling = d2    //買入即期
            }
            if let d3=Double(data0.components(separatedBy: " ")[2]) {
                spotBuying  = d3    //賣出現金
            }
            if let d4=Double(data0.components(separatedBy: " ")[11]) {
                spotSelling = d4    //賣出即期
            }
            if cashSelling == 0 {
                cashSelling = spotSelling
            }
            if spotSelling == 0 {
                spotSelling = cashSelling
            }
            if cashBuying == 0 {
                cashBuying = spotBuying
            }
            if spotBuying == 0 {
                spotBuying = cashBuying
            }
        }
        return (cashBuying,cashSelling,spotBuying,spotSelling)
    }
    

     
}
