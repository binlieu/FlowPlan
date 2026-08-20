import SwiftUI
import FlowPlanDomain

struct UpcomingBillsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSeeAll: () -> Void

    @State private var presentedError: PresentedError?

    init(onSeeAll: @escaping () -> Void = {}) {
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        Section {
            if upcomingBills.isEmpty {
                emptyState
                    .padding(.horizontal, 20)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(upcomingBills) { occurrence in
                    billRow(occurrence)
                        .padding(.horizontal, 20)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.background)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markAsPaid(occurrence)
                            } label: {
                                Label("Mark as paid", systemImage: "checkmark.circle")
                            }
                            .tint(Palette.accent)
                        }
                }
            }
        } header: {
            sectionHeader
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .textCase(nil)
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text("Unable to mark bill as paid"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Upcoming")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 8)

            Button("View All", action: onSeeAll)
                .font(.subheadline.weight(.bold))
                .fontWidth(.condensed)
                .foregroundStyle(Palette.accent)
                .textCase(nil)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No bills remaining")
                .font(.headline)
                .foregroundStyle(Palette.ink)

            Text("There are no unpaid bill occurrences left this month.")
                .font(Typography.supporting)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.surface)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func billRow(_ occurrence: BillOccurrence) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityBillRow(occurrence)
        } else {
            standardBillRow(occurrence)
        }
    }

    private func standardBillRow(_ occurrence: BillOccurrence) -> some View {
        HStack(alignment: .center, spacing: 14) {
            monogram(for: occurrence)

            billDescription(for: occurrence)

            Spacer(minLength: 8)

            amountAndStatus(for: occurrence, alignment: .trailing)
        }
        .padding(14)
        .background(Palette.surface)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func accessibilityBillRow(_ occurrence: BillOccurrence) -> some View {
        HStack(alignment: .top, spacing: 14) {
            monogram(for: occurrence)

            VStack(alignment: .leading, spacing: 12) {
                billDescription(for: occurrence)
                amountAndStatus(for: occurrence, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.surface)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func monogram(for occurrence: BillOccurrence) -> some View {
        Text(occurrence.monogram)
            .smallCapsTypography()
            .foregroundStyle(Palette.accent)
            .frame(width: 54, height: 54)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func billDescription(for occurrence: BillOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(occurrence.bill.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(occurrence.date, format: .dateTime.month(.abbreviated).day())
                .font(Typography.supporting)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func amountAndStatus(
        for occurrence: BillOccurrence,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(money(occurrence.bill.amount))
                .font(.headline.weight(.bold))
                .fontWidth(.condensed)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: true, vertical: true)
                .accessibilityLabel(accessibleMoney(occurrence.bill.amount))

            Text(status(for: occurrence.bill))
                .smallCapsTypography()
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var upcomingBills: [BillOccurrence] {
        _ = projectionStore.projection

        let month = appState.selectedMonth
        let transactions = repository.transactions(in: month)
        let settledBillIDs: [UUID] = transactions.compactMap { transaction -> UUID? in
            guard transaction.type == .expense, let billID = transaction.settlesBillID else {
                return nil
            }
            return billID
        }
        let settledCounts = Dictionary(grouping: settledBillIDs, by: { $0 }).mapValues(\.count)

        let occurrences = repository.bills()
            .filter(\.isActive)
            .flatMap { bill -> [BillOccurrence] in
                let dates = bill.recurrence.occurrences(in: month, calendar: .current)
                let settledCount = settledCounts[bill.id, default: 0]
                return dates.dropFirst(settledCount).map {
                    BillOccurrence(bill: bill, date: $0)
                }
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.bill.name < rhs.bill.name
            }

        return Array(occurrences.prefix(5))
    }

    private func status(for bill: PlannedBill) -> String {
        if bill.isAutoPay {
            return "AUTO PAY"
        }
        if bill.amountType == .estimated {
            return "ESTIMATED"
        }
        return "UPCOMING"
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func markAsPaid(_ occurrence: BillOccurrence) {
        do {
            try repository.markBillPaid(
                billID: occurrence.bill.id,
                occurrence: occurrence.date,
                amount: occurrence.bill.amount,
                on: occurrence.date
            )
            projectionStore.refresh()
        } catch {
            presentedError = PresentedError(
                message: "The bill could not be marked as paid. Please try again."
            )
        }
    }

    private struct BillOccurrence: Identifiable {
        let bill: PlannedBill
        let date: Date

        var id: String {
            "\(bill.id.uuidString)-\(date.timeIntervalSinceReferenceDate)"
        }

        var monogram: String {
            let letters = bill.name.filter(\.isLetter)
            let source = letters.isEmpty ? bill.name : letters
            return String(source.prefix(2)).uppercased()
        }
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

#if DEBUG
#Preview("Upcoming — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        List {
            UpcomingBillsSection()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
}

#Preview("Upcoming — Accessibility") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        List {
            UpcomingBillsSection()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
