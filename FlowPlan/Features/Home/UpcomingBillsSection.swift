import SwiftUI
import FlowPlanDomain

struct UpcomingBillsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAll: () -> Void

    private let calendar: Calendar
    private let now: () -> Date

    @State private var presentedError: BillSettlementError?
    @State private var dismissalRevision = 0
    @State private var isSettlingPromptPayments = false

    init(
        onSeeAll: @escaping () -> Void = {},
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.onSeeAll = onSeeAll
        self.calendar = calendar
        self.now = now
    }

    private var dismissalStore: OverdueAutopayPromptDismissalStore {
        OverdueAutopayPromptDismissalStore(userDefaults: appState.userDefaults)
    }

    var body: some View {
        let _ = projectionStore.dataVersion

        let occurrences = unsettledPaymentOccurrences
        let promptOccurrences = overduePaymentPromptOccurrences(in: occurrences)

        Section {
            if !promptOccurrences.isEmpty {
                autopayPrompt(for: promptOccurrences)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Palette.clear)
                    .listRowSeparator(.hidden)
            }

            if occurrences.isEmpty {
                emptyState
                    .padding(.horizontal, Spacing.lg)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Palette.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(occurrences.prefix(5)) { occurrence in
                    paymentRow(occurrence)
                        .padding(.horizontal, Spacing.lg)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.background)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markAsPaid(occurrence)
                            } label: {
                                Label("Mark as paid", systemImage: "checkmark.circle")
                                    .foregroundStyle(Palette.onAccentFill)
                            }
                            .tint(Palette.accentFill)
                        }
                }
            }
        } header: {
            sectionHeader
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
                .textCase(nil)
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text("Unable to mark payment as paid"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var sectionHeader: some View {
        SectionHeading(title: "Bills", actionTitle: "View All", action: onSeeAll)
    }

    private func autopayPrompt(for occurrences: [HomePaymentOccurrence]) -> some View {
        CardSurface(contentPadding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(Palette.warning)
                        .accessibilityHidden(true)

                    Text(promptMessage(for: occurrences))
                        .rowDetailEmphasisTypography()
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: Spacing.xs)

                    Button {
                        dismissPrompt(for: occurrences)
                    } label: {
                        Image(systemName: "xmark")
                            .captionEmphasisTypography()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityLabel("Dismiss autopay reminder")
                }

                Button("Mark all as paid") {
                    markAllPromptPaymentsAsPaid(occurrences)
                }
                .rowDetailEmphasisTypography()
                .foregroundStyle(Palette.onAccentFill)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentFill)
                .disabled(isSettlingPromptPayments)
            }
        }
    }

    private var emptyState: some View {
        GroupedList(
            emptyState: EmptyStateView(
                symbol: "calendar.badge.checkmark",
                title: "No bills remaining",
                message: "There are no unpaid bills or debt payments left this month.",
                layout: .compact
            )
        )
    }

    private func paymentRow(_ occurrence: HomePaymentOccurrence) -> some View {
        GroupedList([occurrence]) { occurrence in
            ListRow(
                leading: .monogram(occurrence.monogram),
                title: occurrence.name,
                subtitle: occurrence.date.formatted(
                    .dateTime.month(.abbreviated).day()
                ),
                trailingAmount: money(occurrence.amount),
                amountAccessibilityLabel: accessibleMoney(occurrence.amount),
                statuses: statuses(for: occurrence)
            )
        }
    }

    private func statuses(for occurrence: HomePaymentOccurrence) -> [ListRowStatus] {
        let occurrenceStatus = status(for: occurrence)
        var statuses: [ListRowStatus] = []

        if occurrence.isDebt {
            statuses.append(ListRowStatus(text: "DEBT", style: .outlinedAccent))
        }

        if !occurrence.isDebt || occurrenceStatus == .overdue {
            statuses.append(
                ListRowStatus(
                    text: occurrenceStatus.rawValue,
                    style: occurrenceStatus == .overdue ? .warning : .plainAccent,
                    systemImage: occurrenceStatus == .overdue
                        ? "exclamationmark.circle"
                        : nil
                )
            )
        }

        return statuses
    }

    private var unsettledPaymentOccurrences: [HomePaymentOccurrence] {
        let billOccurrences = Self.unsettledOccurrences(
            repository: repository,
            month: appState.selectedMonth,
            relativeTo: now(),
            calendar: calendar
        )

        return Self.paymentOccurrences(
            bills: billOccurrences,
            debts: projectionStore.projection.debtOccurrences,
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

    static func paymentOccurrences(
        bills: [BillOccurrence],
        debts: [DebtOccurrence],
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> [HomePaymentOccurrence] {
        let billPayments = bills.map(HomePaymentOccurrence.bill)
        let debtPayments = debts
            .filter { !$0.isPaidThroughBills }
            .map(HomePaymentOccurrence.debt)

        return HomePaymentOccurrence.sorted(
            billPayments + debtPayments,
            relativeTo: referenceDate,
            calendar: calendar
        )
    }

    private func status(for occurrence: HomePaymentOccurrence) -> BillOccurrenceStatus {
        occurrence.status(relativeTo: now(), calendar: calendar)
    }

    private func overduePaymentPromptOccurrences(
        in occurrences: [HomePaymentOccurrence]
    ) -> [HomePaymentOccurrence] {
        _ = dismissalRevision

        let overdueOccurrences: [HomePaymentOccurrence]
        if appState.recordAutopayAutomatically {
            overdueOccurrences = OverdueAutopaySettlementAction.overdueNonAutopayOccurrences(
                from: occurrences,
                autoPayDebtIDs: autoPayDebtIDs,
                relativeTo: now(),
                calendar: calendar
            )
        } else {
            overdueOccurrences = OverdueAutopaySettlementAction.overdueAutopayOccurrences(
                from: occurrences,
                autoPayDebtIDs: autoPayDebtIDs,
                relativeTo: now(),
                calendar: calendar
            )
        }

        return dismissalStore.undismissedOccurrences(
            in: overdueOccurrences,
            calendar: calendar
        )
    }

    private func promptMessage(for occurrences: [HomePaymentOccurrence]) -> String {
        if appState.recordAutopayAutomatically {
            return "\(occurrences.count) payments were due. Mark them paid?"
        }

        return "\(occurrences.count) autopay payments were due. Mark them paid?"
    }

    private var autoPayDebtIDs: Set<UUID> {
        Set(
            repository.debts()
                .filter { $0.isAutoPay && !$0.isPaidThroughBills }
                .map(\.id)
        )
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func markAsPaid(_ occurrence: HomePaymentOccurrence) {
        presentedError = HomePaymentSettlementAction.markAsPaid(
            occurrence,
            repository: repository,
            projectionStore: projectionStore
        )
    }

    private func markAllPromptPaymentsAsPaid(_ occurrences: [HomePaymentOccurrence]) {
        guard !isSettlingPromptPayments else {
            return
        }

        isSettlingPromptPayments = true
        presentedError = OverdueAutopaySettlementAction.markAllAsPaid(
            occurrences,
            repository: repository,
            projectionStore: projectionStore
        )
        isSettlingPromptPayments = false
    }

    private func dismissPrompt(for occurrences: [HomePaymentOccurrence]) {
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
