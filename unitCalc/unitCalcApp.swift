//
//  unitCalcApp.swift
//  unitCalc
//
//  Created by peiyu on 2023/2/27.
//

import SwiftUI

@main
struct unitCalcApp: App {
    var body: some Scene {
        WindowGroup {
            let calc: calculator = calculator()
            ContentView(calc: calc, cat: calc.cats[1], unit: (calc.units[calc.cats[1]] ?? [])[0])
        }
    }
}
