import SwiftUI
import UIKit

struct AdaptiveResultView: UIViewRepresentable {
    let value: Double
    let inputText: String?
    let errorText: String?
    let fontSize: CGFloat
    let weight: UIFont.Weight

    func makeUIView(context: Context) -> ResultNumberView {
        ResultNumberView()
    }

    func updateUIView(_ view: ResultNumberView, context: Context) {
        view.configure(value: value, inputText: inputText, errorText: errorText,
                       fontSize: fontSize, weight: weight)
    }
}

/// Formatting and UIKit layout share one font and one synchronous layout pass.
/// A changed width never feeds back into the calculator or an asynchronous SwiftUI state.
final class ResultNumberView: UIView {
    let numberLabel = UILabel()
    private(set) var maximumFont = UIFont.systemFont(ofSize: 88)
    private var value: Double = 0
    private var inputText: String?
    private var errorText: String?
    private(set) var usesEmergencyScaling = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        numberLabel.numberOfLines = 1
        numberLabel.adjustsFontSizeToFitWidth = false
        numberLabel.minimumScaleFactor = 1
        numberLabel.textColor = .label
        numberLabel.textAlignment = .right
        numberLabel.accessibilityIdentifier = "calculationResult"
        addSubview(numberLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(value: Double, inputText: String?, errorText: String?, fontSize: CGFloat, weight: UIFont.Weight) {
        let base = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
        maximumFont = UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: fontSize)
        self.value = value
        self.inputText = inputText
        self.errorText = errorText
        setNeedsLayout()
    }

    static func width(of text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 2, bounds.height > 0 else { return }
        // One point at either edge covers rasterization rounding, including minus signs.
        let availableWidth = bounds.width - 2
        let measure: (String) -> CGFloat = { Self.width(of: $0, font: self.maximumFont) }
        let text: String
        if let errorText {
            text = errorText
        } else if let inputText {
            // Inputs always keep every digit; only the whole-string font may shrink.
            text = inputText
        } else {
            text = AdaptiveResultFormatter().format(value, width: availableWidth, measure: measure).text
        }

        // Inputs scale their complete literal; results scale only after the unchanged
        // formatter exhausts compliant representations. Always restart at maximumFont.
        usesEmergencyScaling = measure(text) > availableWidth
        var font = maximumFont
        if usesEmergencyScaling {
            var lower: CGFloat = 0
            var upper = maximumFont.pointSize
            // Font optical metrics can vary with point size. Measure the actual font at
            // every step rather than assuming an exact proportional glyph width.
            for _ in 0..<16 {
                let middle = (lower + upper) / 2
                let candidate = maximumFont.withSize(middle)
                if Self.width(of: text, font: candidate) <= availableWidth {
                    lower = middle
                } else {
                    upper = middle
                }
            }
            font = maximumFont.withSize(lower)
        }
        numberLabel.font = font
        numberLabel.text = text
        numberLabel.frame = bounds.insetBy(dx: 1, dy: 0)
        numberLabel.accessibilityLabel = "計算結果 \(text)"
    }
}
