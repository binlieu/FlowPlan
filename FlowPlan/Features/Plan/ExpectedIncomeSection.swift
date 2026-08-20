import SwiftUI
import FlowPlanDomain

struct ExpectedIncomeSection: View {
    @Environment(AppState.self) private var appState

    let sources: [PlannedIncome]
    let plannedTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (PlannedIncome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                if sources.isEmpty {
                    emptyRow
                } else {
                    ForEach(sources) { source in
                        incomeRow(source)
                        Divider()
                    }
                }

                totalRow
            }
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Expected Income")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 8)

            Button("Add", action: onAdd)
                .font(.subheadline.weight(.bold))
                .fontWidth(.condensed)
                .foregroundStyle(Palette.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private func incomeRow(_ source: PlannedIncome) -> some View {
        Button {
            onEdit(source)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(source.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)

                    Text(subtitle(for: source))
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(signedMoney(source.expectedAmount))
                    .font(.headline.weight(.bold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
            .opacity(source.isActive ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens income editor")
    }

    private var emptyRow: some View {
        Text("No expected income yet.")
            .font(Typography.supporting)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("TOTAL EXPECTED INCOME")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)

            Spacer(minLength: 12)

            Text(signedMoney(plannedTotal))
                .valueTypography()
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .background(Palette.accentLight)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(for source: PlannedIncome) -> String {
        let recurrence = RecurrenceText.summary(source.recurrence)
        return source.isActive ? recurrence : "Inactive · \(recurrence)"
    }

    private func signedMoney(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            signed: true,
            style: .compact
        )
    }
}
