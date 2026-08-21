import SwiftUI

struct StatTile: View {
    @Environment(AppState.self) private var appState
    @ScaledMetric(relativeTo: .subheadline) private var titleAreaHeight: CGFloat = 40

    let title: String
    let symbol: String
    let amount: Decimal
    let secondaryAmount: Decimal?

    init(
        title: String,
        symbol: String,
        amount: Decimal,
        secondaryAmount: Decimal? = nil
    ) {
        self.title = title
        self.symbol = symbol
        self.amount = amount
        self.secondaryAmount = secondaryAmount
    }

    var body: some View {
        TickCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(title.uppercased(), systemImage: symbol)
                    .smallCapsTypography()
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: titleAreaHeight, alignment: .topLeading)

                Text(formattedAmount)
                    .valueTypography()
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel(accessibleAmount)

                Spacer(minLength: Spacing.none)

                if let secondaryAmount {
                    Text("OF \(formattedSecondaryAmount(secondaryAmount))")
                        .smallCapsTypography()
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                        .accessibilityLabel("Of \(accessibleSecondaryAmount(secondaryAmount))")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var formattedAmount: String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private var accessibleAmount: String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func formattedSecondaryAmount(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func accessibleSecondaryAmount(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        Grid(horizontalSpacing: Spacing.sm) {
            GridRow {
                StatTile(
                    title: "Bills Remaining",
                    symbol: "calendar.badge.clock",
                    amount: 680
                )
                StatTile(
                    title: "Savings",
                    symbol: "banknote",
                    amount: 750,
                    secondaryAmount: 2_000
                )
            }
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        Grid(horizontalSpacing: Spacing.sm) {
            GridRow {
                StatTile(
                    title: "Bills Remaining",
                    symbol: "calendar.badge.clock",
                    amount: 680
                )
                StatTile(
                    title: "Savings",
                    symbol: "banknote",
                    amount: 750,
                    secondaryAmount: 2_000
                )
            }
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }
}
#endif
