import SwiftUI

struct StatTile: View {
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: titleAreaHeight, alignment: .topLeading)

            AmountText(amount: amount, style: .primary)

            Spacer(minLength: 0)

            if let secondaryAmount {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("of")
                    AmountText(amount: secondaryAmount, style: .secondary)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        Grid(horizontalSpacing: 12) {
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
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        Grid(horizontalSpacing: 12) {
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
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif
