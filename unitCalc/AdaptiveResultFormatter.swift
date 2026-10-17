import Foundation

/// Presentation only. Never parse this text back into the calculator's operands.
struct AdaptiveResultFormatter {
    // Match the calculator's existing display precision; Double is not arbitrary precision.
    static let significantDigits = 13
    var locale = Locale(identifier: "en_US_POSIX")

    struct Output: Equatable {
        let text: String
        let fits: Bool
    }

    func format(_ value: Double, width: CGFloat, measure: (String) -> CGFloat) -> Output {
        func output(_ text: String) -> Output {
            Output(text: text, fits: measure(text) <= max(0, width))
        }
        guard value.isFinite else { return output("錯誤") }
        // Normalize negative zero, without changing the stored value.
        let value = value == 0 ? 0 : value
        let decimal = makeFormatter(style: .decimal)
        decimal.usesSignificantDigits = true
        decimal.minimumSignificantDigits = 1
        decimal.maximumSignificantDigits = Self.significantDigits
        var full = decimal.string(from: NSNumber(value: value)) ?? String(value)
        let fractionCount = full.components(separatedBy: decimal.decimalSeparator).dropFirst().first?.count ?? 0
        // A carry at the display precision boundary must still retain three decimals.
        if value.rounded(.towardZero) != value, fractionCount < 3,
           decimal.number(from: full)?.doubleValue != value {
            decimal.usesSignificantDigits = false
            decimal.minimumFractionDigits = 3
            decimal.maximumFractionDigits = 3
            full = decimal.string(from: NSNumber(value: value)) ?? full
        }
        if output(full).fits { return output(full) }

        // Below 0.001, prefer a meaningful mantissa to rounding away tiny nonzero values.
        if abs(value) >= 0.001, fractionCount > 3 {
            decimal.usesSignificantDigits = false
            decimal.minimumFractionDigits = 3
            for places in stride(from: fractionCount - 1, through: 3, by: -1) {
                decimal.maximumFractionDigits = places
                guard let text = decimal.string(from: NSNumber(value: value)),
                      decimal.number(from: text)?.doubleValue != 0 else { continue }
                if output(text).fits { return output(text) }
            }
        }

        let scientific = makeFormatter(style: .scientific)
        // ICU pattern supplies an explicit + for positive exponents, with no leading zero.
        scientific.positiveFormat = "0.############E+0"
        scientific.exponentSymbol = "e"
        var precise = scientific.string(from: NSNumber(value: value)) ?? String(value)
        let originalMantissa = precise.components(separatedBy: "e")[0]
        let originalPlaces = originalMantissa.components(separatedBy: scientific.decimalSeparator).dropFirst().first?.count ?? 0
        if originalPlaces < 3, abs(value) >= Double.leastNormalMagnitude,
           scientific.number(from: precise)?.doubleValue != value {
            scientific.minimumFractionDigits = 3
            precise = scientific.string(from: NSNumber(value: value)) ?? precise
        }
        if output(precise).fits { return output(precise) }
        let mantissa = precise.components(separatedBy: "e")[0]
        let places = mantissa.components(separatedBy: scientific.decimalSeparator).dropFirst().first?.count ?? 0
        // Exact simple values (1e+20, 1.5e-8) do not acquire artificial zeros.
        guard places > 3 else { return output(precise) }
        scientific.minimumFractionDigits = 3
        var shortest = precise
        for digits in stride(from: places - 1, through: 3, by: -1) {
            scientific.maximumFractionDigits = digits
            guard let text = scientific.string(from: NSNumber(value: value)) else { continue }
            shortest = text
            // Always measure after rounding: 9.999... can carry into the exponent.
            if output(text).fits { return output(text) }
        }
        return output(shortest)
    }

    private func makeFormatter(style: NumberFormatter.Style) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = style
        formatter.usesGroupingSeparator = style == .decimal
        if style == .decimal, locale.identifier == "en_US_POSIX" {
            formatter.groupingSeparator = ","
            formatter.groupingSize = 3
        }
        formatter.roundingMode = .halfUp
        return formatter
    }
}
