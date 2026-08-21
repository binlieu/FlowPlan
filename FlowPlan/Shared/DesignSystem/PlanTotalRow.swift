import SwiftUI

/// The summary row that closes a Plan section. Every Plan total uses this — income, bills, debt
/// and any added later — so they cannot drift apart again.
struct PlanTotalRow: View {
    @Environment(AppState.self) private var appState

    let label: String
    let amount: Decimal
    var signed: Bool = true // Debt and bills pass false; income keeps the positive sign.
    // GroupedList already separates its footer, so those call sites disable the duplicate rule.
    var showsTopRule: Bool = true
    var contentInsets = EdgeInsets(
        top: Spacing.md,
        leading: Spacing.md,
        bottom: Spacing.md,
        trailing: Spacing.md
    )

    var body: some View {
        VStack(spacing: Spacing.none) {
            if showsTopRule {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text(label)
                    .smallCapsTypography()
                    .foregroundStyle(Palette.accent)

                Spacer(minLength: Spacing.sm)

                Text(formattedAmount)
                    .valueTypography()
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .padding(contentInsets)
        }
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
#Preview("All Plan Totals — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        PlanTotalsPreview()
    }
}

#Preview("All Plan Totals — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        PlanTotalsPreview()
    }
}

#Preview("All Plan Totals — Largest Type") {
    FlowPlanPreviewHost {
        ScrollView {
            PlanTotalsPreview()
                .dynamicTypeSize(.accessibility5)
        }
    }
}

private struct PlanTotalsPreview: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            PlanTotalRow(label: "TOTAL EXPECTED INCOME", amount: 8_500)
            PlanTotalRow(label: "TOTAL MONTHLY BILLS", amount: 2_392.98, signed: false)
            PlanTotalRow(label: "OUTSIDE MONTHLY BILLS", amount: 505, signed: false)
            PlanTotalRow(label: "TOTAL SPENDING BUDGET", amount: 900, signed: false)
            PlanTotalRow(label: "TOTAL SAVINGS GOAL", amount: 1_200, signed: false)
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}
#endif
