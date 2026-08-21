import SwiftUI

/// The tinted summary row that closes a Plan section. Every Plan total uses this — income,
/// bills, debt and any added later — so they cannot drift apart again.
struct PlanTotalRow: View {
    @Environment(AppState.self) private var appState

    let label: String
    let amount: Decimal
    var signed: Bool = true // Debt and bills pass false; income keeps the positive sign.

    static var accentFill: Color {
        Palette.accentLight
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label)
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: Spacing.sm)

            Text(formattedAmount)
                .valueTypography()
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(Spacing.md)
        .background(Self.accentFill)
        .accessibilityElement(children: .combine)
    }

    private var formattedAmount: String {
        if signed {
            return MoneyFormatter.string(
                amount,
                currencyCode: appState.currencyCode,
                signed: true,
                style: .compact
            )
        }

        let magnitude = MoneyFormatter.string(
            abs(amount),
            currencyCode: appState.currencyCode,
            style: .compact
        )
        // Zero has no direction. Prepending the sign unconditionally rendered "-$0", which
        // reads as a negative amount that does not exist.
        return amount == .zero ? magnitude : "-\(magnitude)"
    }
}

#if DEBUG
#Preview("Plan Total Row — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        VStack(spacing: Spacing.sm) {
            PlanTotalRow(label: "TOTAL EXPECTED INCOME", amount: 8_500)
            PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: -2_392.98)
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}

#Preview("Plan Total Row — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        VStack(spacing: Spacing.sm) {
            PlanTotalRow(label: "TOTAL EXPECTED INCOME", amount: 8_500)
            PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: -2_392.98)
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}

#Preview("Plan Total Row — Largest Type") {
    FlowPlanPreviewHost {
        VStack(spacing: Spacing.sm) {
            PlanTotalRow(label: "TOTAL EXPECTED INCOME", amount: 8_500)
            PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: -2_392.98)
        }
        .padding(Spacing.md)
        .background(Palette.background)
        .dynamicTypeSize(.accessibility5)
    }
}

#Preview("All Plan Totals") {
    FlowPlanPreviewHost {
        VStack(spacing: Spacing.sm) {
            PlanTotalRow(label: "TOTAL EXPECTED INCOME", amount: 8_500)
            PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: 2_392.98, signed: false)
            PlanTotalRow(label: "OUTSIDE MONTHLY BILLS", amount: 505, signed: false)
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}
#endif
