//
//  ContentView.swift
//  unitCalc
//
//  Created by peiyu on 2021/4/23.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var calculator: Calculator

    @State private var category: String
    @State private var unit: String
    @State private var didCopyLog = false
    @State private var showsAbout = false
    @ScaledMetric(relativeTo: .body) private var displayTextScale: CGFloat = 1

    init(calculator: Calculator) {
        self.calculator = calculator

        let initialCategory = calculator.categories.first(where: { $0 == "重量" })
            ?? calculator.categories.first
            ?? ""
        let initialUnit = calculator.units[initialCategory]?.first ?? ""
        _category = State(initialValue: initialCategory)
        _unit = State(initialValue: initialUnit)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = CalculatorLayout(size: geometry.size)

            VStack(spacing: layout.sectionSpacing) {
                selectors(layout: layout)
                display(layout: layout)
                CalculatorKeypad(calculator: calculator, layout: layout.keypadLayout)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            calculator.unitConvert(pickerCat: category, pickerUnit: unit)
            await calculator.activate()
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
    }

    @ViewBuilder
    private func selectors(layout: CalculatorLayout) -> some View {
        if layout.usesCompactLandscapeSelector {
            HStack(spacing: layout.selectorSpacing) {
                categoryMenu(layout: layout)
                unitPicker(layout: layout)
                aboutButton(layout: layout)
            }
        } else if layout.keypadLayout == .wide {
            HStack(spacing: 10) {
                categoryPicker(layout: layout)
                    .frame(maxWidth: min(360, layout.size.width * 0.42))
                unitPicker(layout: layout)
                aboutButton(layout: layout)
            }
        } else {
            VStack(spacing: layout.selectorSpacing) {
                HStack(spacing: layout.selectorSpacing) {
                    categoryPicker(layout: layout)
                    aboutButton(layout: layout)
                }
                unitPicker(layout: layout)
            }
        }
    }

    private func categoryPicker(layout: CalculatorLayout) -> some View {
        Picker("換算種類", selection: categoryBinding) {
            ForEach(calculator.categories, id: \.self) { category in
                Text(category).tag(category)
            }
        }
        .pickerStyle(.segmented)
        .font(.system(size: layout.selectorFontSize, weight: .semibold))
        .accessibilityLabel("換算種類")
    }

    private func categoryMenu(layout: CalculatorLayout) -> some View {
        Menu {
            Picker("換算種類", selection: categoryBinding) {
                ForEach(calculator.categories, id: \.self) { categoryName in
                    Text(categoryName).tag(categoryName)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(category)
                    .font(.system(size: layout.selectorFontSize, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: layout.selectorControlHeight)
            .background {
                Capsule()
                    .fill(Color(uiColor: .secondarySystemBackground))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: layout.compactCategoryWidth)
        .accessibilityLabel("換算種類，目前為\(category)")
        .accessibilityHint("選擇貨幣、重量、長度或面積")
    }

    private func aboutButton(layout: CalculatorLayout) -> some View {
        Button {
            showsAbout = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: layout.selectorIconSize))
                .frame(
                    width: layout.selectorControlHeight,
                    height: layout.selectorControlHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("關於與隱私權")
        .accessibilityShowsLargeContentViewer()
    }

    @ViewBuilder
    private func unitPicker(layout: CalculatorLayout) -> some View {
        if category == "貨幣", calculator.currencyTime == nil {
            Label(
                calculator.currencyErrorDescription ?? "正在取得匯率…",
                systemImage: calculator.currencyErrorDescription == nil
                    ? "arrow.triangle.2.circlepath"
                    : "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                minHeight: layout.selectorControlHeight,
                alignment: .leading
            )
            .accessibilityLabel(calculator.currencyErrorDescription ?? "正在取得匯率")
        } else {
            ScrollViewReader { proxy in
                GeometryReader { _ in
                    ZStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(calculator.units[category] ?? [], id: \.self) { unitName in
                                    unitButton(unitName, layout: layout)
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, layout.unitScrollContentPadding)
                            .anchorPreference(
                                key: UnitScrollBoundsPreferenceKey.self,
                                value: .bounds
                            ) { $0 }
                        }
                        .accessibilityIdentifier("unitPicker")
                    }
                    .overlayPreferenceValue(UnitScrollBoundsPreferenceKey.self) { boundsAnchor in
                        GeometryReader { overlay in
                            if let boundsAnchor {
                                let bounds = overlay[boundsAnchor]
                                ZStack {
                                    if bounds.minX < -2 {
                                        unitScrollHint(direction: .left, layout: layout)
                                    }
                                    if bounds.maxX > overlay.size.width + 2 {
                                        unitScrollHint(direction: .right, layout: layout)
                                    }
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: layout.selectorControlHeight)
                .task(id: unit) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(unit, anchor: .center)
                    }
                }
            }
        }
    }

    private func unitButton(_ unitName: String, layout: CalculatorLayout) -> some View {
        Button {
            unitBinding.wrappedValue = unitName
        } label: {
            Text(unitName)
                .font(.system(
                    size: layout.selectorFontSize,
                    weight: unitName == unit ? .semibold : .medium
                ))
                .lineLimit(1)
                .padding(.horizontal, layout.unitHorizontalPadding)
                .frame(minHeight: layout.selectorControlHeight)
                .foregroundStyle(unitName == unit ? Color.white : Color.accentColor)
                .background {
                    Capsule()
                        .fill(unitName == unit ? Color.accentColor : Color.clear)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unitName)
        .accessibilityAddTraits(unitName == unit ? .isSelected : [])
        .accessibilityShowsLargeContentViewer()
        .id(unitName)
    }

    private enum UnitScrollDirection {
        case left
        case right
    }

    private func unitScrollHint(direction: UnitScrollDirection, layout: CalculatorLayout) -> some View {
        HStack(spacing: 0) {
            if direction == .right { Spacer(minLength: 0) }

            ZStack(alignment: direction == .left ? .leading : .trailing) {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .systemBackground).opacity(0)
                    ],
                    startPoint: direction == .left ? .leading : .trailing,
                    endPoint: direction == .left ? .trailing : .leading
                )
                Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, layout.unitScrollHintPadding)
            }
            .frame(width: layout.unitScrollHintWidth, height: layout.selectorControlHeight)

            if direction == .left { Spacer(minLength: 0) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func display(layout: CalculatorLayout) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(displayLogText)
                            .font(.system(size: scaledFontSize(layout.logFontSize, maximumScale: 1.4)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .id("logEnd")
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .task(id: displayLogText) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("logEnd", anchor: .trailing)
                        }
                    }
                }

                if calculator.hasHistory {
                    Button {
                        UIPasteboard.general.string = calculator.logText.replacingOccurrences(of: " ", with: "")
                        didCopyLog = true
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            didCopyLog = false
                        }
                    } label: {
                        Image(systemName: didCopyLog ? "doc.on.doc.fill" : "doc.on.doc")
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(didCopyLog ? "已複製計算紀錄" : "複製計算紀錄")
                    .accessibilityShowsLargeContentViewer()
                }
            }
            .padding(.horizontal, layout.displayHorizontalPadding)
            .frame(height: layout.logHeight)

            Text(calculator.textCurrent)
                .font(.system(
                    size: scaledFontSize(layout.outputFontSize, maximumScale: 1.3),
                    weight: layout.outputFontWeight,
                    design: .rounded
                ))
                .monospacedDigit()
                .minimumScaleFactor(0.22)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.horizontal, layout.displayHorizontalPadding)
                .accessibilityLabel("計算結果 \(calculator.textCurrent)")

            Text(memoryText)
                .font(.system(
                    size: scaledFontSize(layout.memoryFontSize, maximumScale: 1.4),
                    weight: .medium,
                    design: .rounded
                ))
                .monospacedDigit()
                .foregroundStyle(.brown)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.displayHorizontalPadding)
                .frame(height: layout.memoryHeight)
        }
        .frame(height: layout.displayHeight)
        .background {
            RoundedRectangle(cornerRadius: layout.panelCornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { category },
            set: { newCategory in
                guard newCategory != category else { return }
                category = newCategory

                guard let firstUnit = calculator.units[newCategory]?.first else { return }
                unit = firstUnit
                calculator.unitConvert(pickerCat: newCategory, pickerUnit: firstUnit)
            }
        )
    }

    private var unitBinding: Binding<String> {
        Binding(
            get: { unit },
            set: { newUnit in
                guard newUnit != unit else { return }
                unit = newUnit
                calculator.unitConvert(pickerCat: category, pickerUnit: newUnit)
            }
        )
    }

    private var memoryText: String {
        guard let value = calculator.valueMemory else { return " " }
        return "m = \(calculator.outputText(value))"
    }

    private var displayLogText: String {
        if let error = calculator.calculationErrorDescription {
            return error
        }

        let log = calculator.logText
        guard category == "貨幣", let timestamp = calculator.currencyTime else {
            return log.isEmpty ? " " : log
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "M/d HH:mm"
        let source = calculator.currencySource == "台灣銀行"
            ? "台灣銀行現金賣出"
            : calculator.currencySource
        var status = "\(source) · \(formatter.string(from: timestamp))"
        if calculator.currencyErrorDescription != nil {
            status += " · 更新失敗，沿用快取"
        }
        return log.isEmpty ? status : "\(status) · \(log)"
    }

    private func scaledFontSize(_ base: CGFloat, maximumScale: CGFloat) -> CGFloat {
        min(base * displayTextScale, base * maximumScale)
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("unitCalc 不需要帳號，也不使用廣告、分析或追蹤服務。")
                    Text("貨幣匯率主要取自臺灣銀行；臺灣銀行暫時無法使用時，改用中央銀行參考匯率。")
                } header: {
                    Text("資料與隱私")
                }

                Section {
                    Text("匯率資料僅供換算參考，不代表任何金融機構的實際交易報價；實際匯率應以交易時相關金融機構公告為準。")
                    Text("unitCalc 為獨立開發工具，與臺灣銀行及中央銀行沒有隸屬、合作、代理或背書關係。")
                    Text("中央銀行資料依政府資料開放授權條款第 1 版使用。")
                } header: {
                    Text("匯率資料與免責聲明")
                }

                Section {
                    Link(
                        "隱私權政策",
                        destination: URL(string: "https://peiyu66.github.io/unitCalc/docs/PrivacyPolicy.html")!
                    )
                    Link(
                        "臺灣銀行牌告匯率",
                        destination: URL(string: "https://rate.bot.com.tw/xrt?Lang=zh-TW")!
                    )
                    Link(
                        "中央銀行重要金融統計",
                        destination: URL(string: "https://cpx.cbc.gov.tw/API/DataAPI/Get?FileName=BP01D01")!
                    )
                    Link(
                        "政府資料開放授權條款第 1 版",
                        destination: URL(string: "https://data.gov.tw/license")!
                    )
                }

                Section {
                    Text(versionDescription)
                }
            }
            .navigationTitle("關於 unitCalc")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "—"
        return "版本 \(version)（\(build)）"
    }
}

private struct UnitScrollBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct CalculatorKeypad: View {
    @ObservedObject var calculator: Calculator
    let layout: KeypadLayout
    @ScaledMetric(relativeTo: .title2) private var keypadTextScale: CGFloat = 1

    private let compactLabels = [
        ["C", "mc", "mr", "ms"],
        ["7", "8", "9", "/"],
        ["4", "5", "6", "*"],
        ["1", "2", "3", "-"],
        ["0", ".", "=", "+"]
    ]

    private let wideLabels = [
        ["C", "十億", "十萬", "7", "8", "9", "/", "CE"],
        ["mc", "百億", "百萬", "4", "5", "6", "*", "∛"],
        ["mr", "千億", "千萬", "1", "2", "3", "-", "√"],
        ["ms", "兆", "億", "0", ".", "=", "+", "x²"]
    ]

    private let padLabels = [
        ["C", "mc", "mr", "ms", "CE"],
        ["7", "8", "9", "/", "x³"],
        ["4", "5", "6", "*", "∛"],
        ["1", "2", "3", "-", "√"],
        ["0", ".", "=", "+", "x²"]
    ]

    var body: some View {
        GeometryReader { geometry in
            let rows = labels.count
            let columnsCount = labels.first?.count ?? 1
            let spacing = layout.spacing
            let availableHeight = geometry.size.height - (spacing * CGFloat(max(rows - 1, 0)))
            let cellHeight = max(1, availableHeight / CGFloat(rows))
            let columns = Array(
                repeating: GridItem(.flexible(minimum: 44), spacing: spacing),
                count: columnsCount
            )

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(labels.joined().enumerated()), id: \.offset) { _, key in
                    keyButton(key, height: cellHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var labels: [[String]] {
        switch layout {
        case .compact:
            compactLabels
        case .pad:
            padLabels
        case .wide:
            wideLabels
        }
    }

    private func keyButton(_ key: String, height: CGFloat) -> some View {
        let enabled = calculator.isKeyEnabled(key)

        return Button {
            calculator.keyin(key, byUser: true)
        } label: {
            Group {
                if let imageName = systemImageName[key] {
                    Image(systemName: imageName)
                } else {
                    Text(key == "." ? "•" : key)
                }
            }
            .font(.system(
                size: fontSize(for: key, cellHeight: height),
                weight: layout.fontWeight,
                design: .rounded
            ))
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
        .background {
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .stroke(Color.accentColor.opacity(enabled ? 0.75 : 0.2), lineWidth: 1)
        }
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel(for: key))
        .accessibilityShowsLargeContentViewer()
    }

    private var systemImageName: [String: String] {
        ["*": "multiply", "/": "divide", "+": "plus", "-": "minus", "=": "equal"]
    }

    private func fontSize(for key: String, cellHeight: CGFloat) -> CGFloat {
        let isLongLabel = key.count > 1 || calculator.isOperator(key) || calculator.isPowerOfTen(key)
        let scale: CGFloat = isLongLabel ? layout.longLabelScale : layout.labelScale
        let baseSize = min(layout.maximumFontSize, max(16, cellHeight * scale))
        return min(layout.maximumFontSize * 1.25, baseSize * keypadTextScale)
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "C": "清除"
        case "CE": "復原上一步"
        case "mc": "清除記憶"
        case "mr": "讀取記憶"
        case "ms": "儲存至記憶"
        case "+": "加"
        case "-": "減"
        case "*": "乘"
        case "/": "除"
        case "=": "等於"
        case ".": "小數點"
        case "√": "平方根"
        case "∛": "立方根"
        case "x²": "平方"
        case "x³": "立方"
        default: key
        }
    }
}

private enum KeypadLayout {
    case compact
    case pad
    case wide

    var spacing: CGFloat {
        switch self {
        case .compact: 6
        case .pad: 9
        case .wide: 6
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: 14
        case .pad: 18
        case .wide: 16
        }
    }

    var labelScale: CGFloat {
        switch self {
        case .compact: 0.54
        case .pad: 0.52
        case .wide: 0.50
        }
    }

    var longLabelScale: CGFloat {
        switch self {
        case .compact: 0.36
        case .pad: 0.40
        case .wide: 0.38
        }
    }

    var maximumFontSize: CGFloat {
        switch self {
        case .compact: 48
        case .pad, .wide: 76
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .compact: .regular
        case .pad, .wide: .medium
        }
    }
}

private struct CalculatorLayout {
    let size: CGSize

    var keypadLayout: KeypadLayout {
        if size.width > size.height {
            return .wide
        }
        return size.width >= 600 ? .pad : .compact
    }

    var horizontalPadding: CGFloat {
        switch keypadLayout {
        case .compact: 8
        case .pad: 16
        case .wide: 12
        }
    }

    var verticalPadding: CGFloat {
        keypadLayout == .wide ? 4 : 10
    }

    var sectionSpacing: CGFloat {
        switch keypadLayout {
        case .compact: 8
        case .pad: 10
        case .wide: 6
        }
    }

    var selectorSpacing: CGFloat {
        usesCompactLandscapeSelector ? 8 : (keypadLayout == .wide ? 5 : 8)
    }

    var usesCompactLandscapeSelector: Bool {
        keypadLayout == .wide && size.height < 390
    }

    var compactCategoryWidth: CGFloat {
        min(110, max(96, size.width * 0.14))
    }

    var unitHorizontalPadding: CGFloat {
        if usesCompactLandscapeSelector {
            return 10
        }
        return keypadLayout == .compact ? 12 : 16
    }

    var selectorControlHeight: CGFloat {
        usesCompactLandscapeSelector ? 34 : 44
    }

    var selectorFontSize: CGFloat {
        usesCompactLandscapeSelector || keypadLayout == .compact ? 15 : 18
    }

    var selectorIconSize: CGFloat {
        usesCompactLandscapeSelector ? 20 : 22
    }

    var unitScrollContentPadding: CGFloat {
        usesCompactLandscapeSelector ? 16 : 1
    }

    var unitScrollHintWidth: CGFloat {
        usesCompactLandscapeSelector ? 36 : 52
    }

    var unitScrollHintPadding: CGFloat {
        usesCompactLandscapeSelector ? 6 : 8
    }

    var displayHeight: CGFloat {
        switch keypadLayout {
        case .compact:
            return max(150, size.height * 0.28)
        case .pad:
            return max(180, size.height * 0.29)
        case .wide:
            guard usesCompactLandscapeSelector else {
                return min(320, max(180, size.height * 0.30))
            }

            let idealHeight = min(140, max(96, size.height * 0.26))

            let selectorHeight = selectorControlHeight
            let keypadMinimumHeight = (44 * 4) + (KeypadLayout.wide.spacing * 3)
            let fixedHeight = (verticalPadding * 2) + (sectionSpacing * 2) + selectorHeight
            let heightPreservingMinimumKeypad = size.height - fixedHeight - keypadMinimumHeight
            return min(idealHeight, max(72, heightPreservingMinimumKeypad))
        }
    }

    var logHeight: CGFloat {
        switch keypadLayout {
        case .compact:
            return max(34, displayHeight * 0.18)
        case .pad:
            return max(38, displayHeight * 0.16)
        case .wide:
            return usesCompactLandscapeSelector
                ? compactLandscapeAuxiliaryHeight
                : max(34, displayHeight * 0.14)
        }
    }

    var memoryHeight: CGFloat {
        switch keypadLayout {
        case .compact:
            return max(32, displayHeight * 0.18)
        case .pad:
            return max(38, displayHeight * 0.16)
        case .wide:
            return usesCompactLandscapeSelector
                ? compactLandscapeAuxiliaryHeight
                : max(34, displayHeight * 0.14)
        }
    }

    private var compactLandscapeAuxiliaryHeight: CGFloat {
        min(24, max(18, displayHeight * 0.22))
    }

    var logFontSize: CGFloat {
        switch keypadLayout {
        case .compact:
            return min(26, max(14, displayHeight * 0.10))
        case .pad:
            return min(34, max(16, displayHeight * 0.10))
        case .wide:
            return min(30, max(16, displayHeight * 0.10))
        }
    }

    var outputFontSize: CGFloat {
        switch keypadLayout {
        case .compact:
            return min(88, displayHeight * 0.48)
        case .pad:
            return min(196, displayHeight * 0.55)
        case .wide:
            return usesCompactLandscapeSelector
                ? min(96, displayHeight * 0.70)
                : min(190, displayHeight * 0.62)
        }
    }

    var outputFontWeight: Font.Weight {
        usesCompactLandscapeSelector ? .medium : .regular
    }

    var memoryFontSize: CGFloat {
        switch keypadLayout {
        case .compact:
            return min(30, max(16, displayHeight * 0.12))
        case .pad:
            return min(44, max(18, displayHeight * 0.13))
        case .wide:
            return min(38, max(18, displayHeight * 0.12))
        }
    }

    var displayHorizontalPadding: CGFloat {
        keypadLayout == .compact ? 10 : 16
    }

    var panelCornerRadius: CGFloat {
        keypadLayout == .compact ? 18 : 22
    }
}

#Preview("iPhone 13 mini") {
    ContentView(calculator: Calculator())
}
