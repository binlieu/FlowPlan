import SwiftUI
import FlowPlanDomain

enum ExpectedIncomeOccurrenceStatus: String, Equatable {
    case overdue = "OVERDUE"
    case expected = "EXPECTED"

    static func status(
        for occurrenceDate: Date,
        relativeTo referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        calendar.startOfDay(for: occurrenceDate) < calendar.startOfDay(for: referenceDate)
            ? .overdue
            : .expected
    }
}

enum ExpectedIncomeSettlementError: String, Identifiable, Equatable {
    case alreadyReceived
    case invalidAmount
    case unableToRecord

    var id: String { rawValue }

    var message: String {
        switch self {
        case .alreadyReceived:
            return "This income occurrence has already been marked as received."
        case .invalidAmount:
            return "Enter an amount greater than zero."
        case .unableToRecord:
            return "The income could not be marked as received. Please try again."
        }
    }
}

@MainActor
enum ExpectedIncomeSettlementAction {
    @discardableResult
    static func markAsReceived(
        _ occurrence: TransactionSettlementOccurrence,
        amount: Decimal,
        repository: FinanceRepository,
        projectionStore: ProjectionStore,
        calendar: Calendar = .current
    ) -> ExpectedIncomeSettlementError? {
        let month = MonthKey(date: occurrence.occurrenceDate, calendar: calendar)
        let isStillUnsettled = TransactionSettlementOccurrenceProvider(
            repository: repository,
            calendar: calendar
        ).unsettledOccurrences(for: .income, in: month).contains {
            $0.id == occurrence.id
        }
        guard isStillUnsettled else {
            return .alreadyReceived
        }

        do {
            try repository.markIncomeReceived(
                incomeID: occurrence.sourceID,
                amount: amount,
                on: occurrence.occurrenceDate
            )
            projectionStore.refresh()
            return nil
        } catch FinanceRepositoryError.settlementAlreadyRecorded {
            return .alreadyReceived
        } catch FinanceRepositoryError.nonPositiveAmount {
            return .invalidAmount
        } catch {
            return .unableToRecord
        }
    }
}

struct ExpectedIncomeSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSeeAll: () -> Void

    private let calendar: Calendar
    private let now: () -> Date

    @State private var presentedOccurrence: TransactionSettlementOccurrence?
    @State private var presentedError: ExpectedIncomeSettlementError?

    init(
        onSeeAll: @escaping () -> Void = {},
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.onSeeAll = onSeeAll
        self.calendar = calendar
        self.now = now
    }

    var body: some View {
        let _ = projectionStore.dataVersion

        if !unsettledOccurrences.isEmpty {
            Section {
                ForEach(visibleOccurrences) { occurrence in
                    incomeRow(occurrence)
                        .padding(.horizontal, 20)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Palette.background)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                markAsReceived(occurrence, amount: occurrence.amount)
                            } label: {
                                Label("Mark as received", systemImage: "checkmark.circle")
                                    .foregroundStyle(Palette.onAccentFill)
                            }
                            .tint(Palette.accentFill)
                            .accessibilityLabel("Mark \(occurrence.name) as received")
                        }
                }
            } header: {
                sectionHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .textCase(nil)
            }
            .sheet(item: $presentedOccurrence) { occurrence in
                IncomeReceiptConfirmationSheet(
                    occurrence: occurrence,
                    currencyCode: appState.currencyCode
                ) { amount in
                    ExpectedIncomeSettlementAction.markAsReceived(
                        occurrence,
                        amount: amount,
                        repository: repository,
                        projectionStore: projectionStore,
                        calendar: calendar
                    )
                }
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text("Unable to mark income as received"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Expected income")
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

    @ViewBuilder
    private func incomeRow(_ occurrence: TransactionSettlementOccurrence) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityIncomeRow(occurrence)
        } else {
            standardIncomeRow(occurrence)
        }
    }

    private func standardIncomeRow(
        _ occurrence: TransactionSettlementOccurrence
    ) -> some View {
        Button {
            presentedOccurrence = occurrence
        } label: {
            HStack(alignment: .center, spacing: 14) {
                monogram(for: occurrence)
                incomeDescription(for: occurrence)
                Spacer(minLength: 8)
                amountAndStatus(for: occurrence, alignment: .trailing)
            }
            .padding(14)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: occurrence))
        .accessibilityHint("Opens confirmation to mark this income as received")
    }

    private func accessibilityIncomeRow(
        _ occurrence: TransactionSettlementOccurrence
    ) -> some View {
        Button {
            presentedOccurrence = occurrence
        } label: {
            HStack(alignment: .top, spacing: 14) {
                monogram(for: occurrence)

                VStack(alignment: .leading, spacing: 12) {
                    incomeDescription(for: occurrence)
                    amountAndStatus(for: occurrence, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: occurrence))
        .accessibilityHint("Opens confirmation to mark this income as received")
    }

    private func monogram(for occurrence: TransactionSettlementOccurrence) -> some View {
        Text(monogramText(for: occurrence.name))
            .smallCapsTypography()
            .foregroundStyle(Palette.accent)
            .frame(width: 54, height: 54)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func incomeDescription(
        for occurrence: TransactionSettlementOccurrence
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(occurrence.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(occurrence.occurrenceDate, format: .dateTime.month(.abbreviated).day())
                .font(Typography.supporting)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func amountAndStatus(
        for occurrence: TransactionSettlementOccurrence,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 5) {
            Text(money(occurrence.amount))
                .font(.headline.weight(.bold))
                .fontWidth(.condensed)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: true, vertical: true)

            let status = status(for: occurrence)
            OccurrenceStatusLabel(
                text: status.rawValue,
                isOverdue: status == .overdue
            )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unsettledOccurrences: [TransactionSettlementOccurrence] {
        return Self.unsettledOccurrences(
            repository: repository,
            month: appState.selectedMonth,
            calendar: calendar
        )
    }

    private var visibleOccurrences: [TransactionSettlementOccurrence] {
        Array(unsettledOccurrences.prefix(5))
    }

    static func unsettledOccurrences(
        repository: FinanceRepository,
        month: MonthKey,
        calendar: Calendar
    ) -> [TransactionSettlementOccurrence] {
        TransactionSettlementOccurrenceProvider(
            repository: repository,
            calendar: calendar
        ).unsettledOccurrences(for: .income, in: month)
    }

    private func status(
        for occurrence: TransactionSettlementOccurrence
    ) -> ExpectedIncomeOccurrenceStatus {
        ExpectedIncomeOccurrenceStatus.status(
            for: occurrence.occurrenceDate,
            relativeTo: now(),
            calendar: calendar
        )
    }

    private func accessibilityLabel(
        for occurrence: TransactionSettlementOccurrence
    ) -> String {
        let date = occurrence.occurrenceDate.formatted(
            .dateTime.month(.wide).day().year()
        )
        return "\(occurrence.name), \(date), \(accessibleMoney(occurrence.amount)), "
            + status(for: occurrence).rawValue.lowercased()
    }

    private func monogramText(for name: String) -> String {
        let letters = name.filter(\.isLetter)
        let source = letters.isEmpty ? name : letters
        return String(source.prefix(2)).uppercased()
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(amount, currencyCode: appState.currencyCode)
    }

    private func accessibleMoney(_ amount: Decimal) -> String {
        MoneyFormatter.accessibleString(amount, currencyCode: appState.currencyCode)
    }

    private func markAsReceived(
        _ occurrence: TransactionSettlementOccurrence,
        amount: Decimal
    ) {
        presentedError = ExpectedIncomeSettlementAction.markAsReceived(
            occurrence,
            amount: amount,
            repository: repository,
            projectionStore: projectionStore,
            calendar: calendar
        )
    }
}

private struct IncomeReceiptConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let occurrence: TransactionSettlementOccurrence
    let currencyCode: String
    let onConfirm: (Decimal) -> ExpectedIncomeSettlementError?

    @State private var amountText: String
    @State private var presentedError: ExpectedIncomeSettlementError?
    @State private var isSaving = false

    init(
        occurrence: TransactionSettlementOccurrence,
        currencyCode: String,
        onConfirm: @escaping (Decimal) -> ExpectedIncomeSettlementError?
    ) {
        self.occurrence = occurrence
        self.currencyCode = currencyCode
        self.onConfirm = onConfirm
        _amountText = State(initialValue: PlanAmountParser.text(occurrence.amount))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(occurrence.name)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)

                    Text(occurrence.occurrenceDate, format: .dateTime.month(.wide).day().year())
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                }

                HStack(spacing: 12) {
                    TextField("Amount received", text: $amountText)
                        .font(.title2.weight(.bold))
                        .fontWidth(.condensed)
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Amount received")

                    Text(currencyCode)
                        .smallCapsTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(14)
                .background(Palette.surface)
                .overlay {
                    Rectangle().stroke(Palette.hairline, lineWidth: 1)
                }

                if let presentedError {
                    Text(presentedError.message)
                        .font(Typography.supporting)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Mark as received", action: confirm)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Palette.onAccentFill)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.large)
                    .disabled(parsedAmount.map { $0 <= .zero } ?? true || isSaving)
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Palette.background)
            .navigationTitle("Confirm income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
    }

    private var parsedAmount: Decimal? {
        PlanAmountParser.decimal(from: amountText)
    }

    private func confirm() {
        guard let amount = parsedAmount, amount > .zero else {
            presentedError = .invalidAmount
            return
        }

        isSaving = true
        if let error = onConfirm(amount) {
            presentedError = error
            isSaving = false
        } else {
            dismiss()
        }
    }
}

#if DEBUG
#Preview("Expected Income — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        List {
            ExpectedIncomeSection()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
}

#Preview("Expected Income — Accessibility") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        List {
            ExpectedIncomeSection()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
