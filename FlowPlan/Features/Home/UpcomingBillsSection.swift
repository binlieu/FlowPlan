import SwiftUI
import FlowPlanDomain

struct UpcomingBillsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAll: () -> Void

    @State private var presentedError: PresentedError?

    init(onSeeAll: @escaping () -> Void = {}) {
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        Section {
            if upcomingBills.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.checkmark",
                    title: "No bills remaining",
                    message: "There are no unpaid bill occurrences left this month."
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(upcomingBills) { occurrence in
                    billRow(occurrence)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markAsPaid(occurrence)
                            } label: {
                                Label("Mark as paid", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                }
            }
        } header: {
            sectionHeader
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
        HStack(alignment: .firstTextBaseline) {
            Text("Upcoming Bills")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button("See all", action: onSeeAll)
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
        }
    }

    private func billRow(_ occurrence: BillOccurrence) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.bill.name)
                    .font(.body.weight(.medium))

                Text(occurrence.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            AmountText(amount: occurrence.bill.amount, style: .secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
    }

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        List {
            UpcomingBillsSection()
        }
        .listStyle(.insetGrouped)
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        List {
            UpcomingBillsSection()
        }
        .listStyle(.insetGrouped)
    }
}
#endif
