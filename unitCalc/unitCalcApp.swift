//
//  unitCalcApp.swift
//  unitCalc
//
//  Created by peiyu on 2023/2/27.
//

import SwiftUI

@main
struct UnitCalcApp: App {
    @StateObject private var calculator = Calculator()

    var body: some Scene {
        WindowGroup {
            ContentView(calculator: calculator)
        }
    }
}
