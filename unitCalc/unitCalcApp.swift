//
//  unitCalcApp.swift
//  unitCalc
//
//  Created by peiyu on 2023/2/27.
//

import SwiftUI

@main
struct UnitCalcApp: App {
    @StateObject private var calculator: Calculator = {
        let calculator = Calculator()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--unitcalc-result-value"),
           arguments.indices.contains(index + 1),
           let value = Double(arguments[index + 1]), value.isFinite {
            calculator.valueCurrent = value
            calculator.valueOperant = value
            calculator.textCurrent = calculator.outputText(value)
        }
        #endif
        return calculator
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(calculator: calculator)
        }
    }
}
