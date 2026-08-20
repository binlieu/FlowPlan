import SwiftUI
import FlowPlanDomain

struct UpcomingBillsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSeeAll: () -> Void

    private let calendar: Calendar
    private let now: () -> Date
    private let dismissalStore: OverdueAutopayPromptDismissalStore

    @State private var presentedError: BillSettlementError?
    @State private var dismissalRevision = 0
    @State private var isSettlingAutopayBills = false

    init(
        onSeeAll: @escaping () -> Void = {},
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        userDefaults: UserDefaults = .standard
    ) {
        self.onSeeAll = onSeeAll
        self.calendar = calendar
        self.now = now
        dismissalStore = OverdueAutopayPromptDismissalStore(userDefaults: userDefaults)
    }

    var body: some View {
        let occurrences = unsettledOccurrences
        let promptOccurrences = overdueAutopayPromptOccurrences(in: occurrences)

        Section {
            if !promptOccurrences.isEmpty {
                autopayPrompt(for: promptOccurrences)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if occurrences.isEmpty {
                emptyState
                    .padding(.horizontal, 20)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(occurrences.prefix(5)) { occurrence in
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
            Text("Bills")
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

    private func autopayPrompt(for occurrences: [BillOccurrence]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("\(occurrences.count) autopay bills were due. Mark them paid?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    dismissPrompt(for: occurrences)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityLabel("Dismiss autopay reminder")
            }

            Button("Mark all as paid") {
                markAllAutopayBillsAsPaid(occurrences)
            }
            .font(.subheadline.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .disabled(isSettlingAutopayBills)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.surface)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
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

            let status = status(for: occurrence)
            OccurrenceStatusLabel(
                text: status.rawValue,
                isOverdue: status == .overdue
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unsettledOccurrences: [BillOccurrence] {
        _ = projectionStore.projection

        return Self.unsettledOccurrences(
            repository: repository,
            month: appState.selectedMonth,
            relativeTo: now(),
            calendar: calendar
        )
    }

    static func unsettledOccurrences(
        repository: FinanceRepository,
        month: MonthKey,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [BillOccurrence] {
        BillOccurrenceProvider(
            repository: repository,
            calendar: calendar
        ).unsettledOccurrences(in: month, relativeTo: referenceDate)
    }

    static func sortedOccurrences(
        _ occurrences: [BillOccurrence],
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [BillOccurrence] {
        BillOccurrenceProvider.sortedOccurrences(
            occurrences,
            relativeTo: referenceDate,
            calendar: calendar
        )
    }

    private func status(for occurrence: BillOccurrence) -> BillOccurrenceStatus {
        BillOccurrenceStatus.status(
            for: occurrence.bill,
            occurrenceDate: occurrence.date,
            relativeTo: now(),
            calendar: calendar
        )
    }

    private func overdueAutopayPromptOccurrences(
        in occurrences: [BillOccurrence]
    ) -> [BillOccurrence] {
        _ = dismissalRevision

        let referenceDate = now()
        let overdueAutopayOccurrences = occurrences.filter { occurrence in
            occurrence.bill.isAutoPay
                && BillOccurrenceStatus.status(
                    for: occurrence.bill,
                    occurrenceDate: occurrence.date,
                    relativeTo: referenceDate,
                    calendar: calendar
                ) == .overdue
        }
        return dismissalStore.undismissedOccurrences(
            in: overdueAutopayOccurrences,
            calendar: calendar
        )
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
            presentedError = .unableToRecord
        }
    }

    private func markAllAutopayBillsAsPaid(_ occurrences: [BillOccurrence]) {
        guard !isSettlingAutopayBills else {
            return
        }

        isSettlingAutopayBills = true
        presentedError = OverdueAutopaySettlementAction.markAllAsPaid(
            from: occurrences,
            relativeTo: now(),
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar
        )
        isSettlingAutopayBills = false
    }

    private func dismissPrompt(for occurrences: [BillOccurrence]) {
        dismissalStore.dismiss(occurrences, calendar: calendar)
        dismissalRevision += 1
    }
}

#if DEBUG
#Preview("Bills — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        List {
            UpcomingBillsSection()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
}

#Preview("Bills — Accessibility") {
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
