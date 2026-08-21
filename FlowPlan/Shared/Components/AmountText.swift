import SwiftUI

enum AmountTextStyle {
    case hero
    case primary
    case secondary
}

struct AmountText: View {
    @Environment(AppState.self) private var appState

    let amount: Decimal
    let style: AmountTextStyle
    let signed: Bool
    let emphasiseNegative: Bool
    let color: Color?

    init(
        amount: Decimal,
        style: AmountTextStyle = .primary,
        signed: Bool = false,
        emphasiseNegative: Bool = false,
        color: Color? = nil
    ) {
        self.amount = amount
        self.style = style
        self.signed = signed
        self.emphasiseNegative = emphasiseNegative
        self.color = color
    }

    var body: some View {
        Group {
            switch style {
            case .hero:
                Text(formattedAmount)
                    .formAmountTypography()
                    .contentTransition(.numericText())
            case .primary:
                Text(formattedAmount)
                    .prominentLabelTypography()
            case .secondary:
                Text(formattedAmount)
                    .rowDetailTypography()
            }
        }
        .monospacedDigit()
        .foregroundStyle(foregroundColor)
        .accessibilityLabel(accessibleAmount)
    }

    private var formattedAmount: String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: signed
        )
    }

    private var accessibleAmount: String {
        let value = MoneyFormatter.accessibleString(
            amount,
            currencyCode: appState.currencyCode
        )

        if signed, amount > .zero {
            return "Plus \(value)"
        }

        return value
    }

    private var foregroundColor: Color {
        if let color {
            return color
        }

        return emphasiseNegative && amount < .zero ? Palette.negative : Palette.ink
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AmountText(amount: 1_420, style: .hero)
            AmountText(amount: 220, signed: true)
            AmountText(amount: -420, style: .secondary, emphasiseNegative: true)
        }
        .padding(Spacing.md)
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AmountText(amount: 1_420, style: .hero)
            AmountText(amount: 220, signed: true)
            AmountText(amount: -420, style: .secondary, emphasiseNegative: true)
        }
        .padding(Spacing.md)
    }
}
#endif
