import SwiftData
import SwiftUI
import FlowPlanDomain

struct SavingsGoalSection: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Query private var storedGoals: [SavingsGoalEntity]

    let plans: [SavingsPlan]
    let projection: MonthlyProjection
    let plannedTotal: Decimal
    let onAdd: () -> Void
    let onEdit: (SavingsPlan) -> Void
    let onPreviewTarget: (Decimal?) -> Void

    struct TotalRowContent: Equatable {
        let label: String
        let amount: Decimal
    }

    @State private var sliderValue = 0.0
    @State private var sliderUpperBound = 4_000.0
    @State private var isDragging = false
    @State private var isInactiveExpanded = false
    @State private var presentedError: WriteErrorPresentation?
    @State private var pendingDeletion: PendingGoalDeletion?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader

            GroupedList(
                plans.prefix(1),
                emptyState: EmptyStateView(
                    symbol: "target",
                    title: "Add a savings goal to reserve money in your monthly plan.",
                    layout: .compact
                ),
                footer: AnyView(totalRow),
                rowContent: goalSummary
            )

            if !inactiveGoals.isEmpty {
                inactiveGoalsGroup
            }
        }
        .onAppear(perform: synchronizeSlider)
        .onChange(of: projection.savingsTarget) {
            guard !isDragging else {
                return
            }
            synchronizeSlider()
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Delete inactive savings goal?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDeletion {
                    deleteInactiveGoal(id: pendingDeletion.id)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            if let pendingDeletion {
                Text("This permanently deletes \(pendingDeletion.name).")
            }
        }
    }

    private var sectionHeader: some View {
        SectionHeading(
            title: "Savings Goal",
            actionTitle: plans.first == nil ? "Add" : "Edit",
            action: plans.first.map { plan in { onEdit(plan) } } ?? onAdd
        )
    }

    private var totalRow: some View {
        let content = Self.totalRowContent(plannedTotal: plannedTotal)

        return PlanTotalRow(
            label: content.label,
            amount: content.amount,
            signed: false
        )
    }

    static func totalRowContent(plannedTotal: Decimal) -> TotalRowContent {
        TotalRowContent(
            label: "TOTAL SAVINGS GOAL",
            amount: plannedTotal
        )
    }

    private func goalSummary(_ plan: SavingsPlan) -> some View {
        VStack(spacing: Spacing.none) {
            ListRow(
                title: plan.name,
                subtitle: "Saved this month",
                trailingAmount: "\(money(projection.savingsCompleted)) of \(money(projection.savingsTarget))",
                amountStyle: .secondary
            ) {
                ProgressView(value: savingsProgress)
                    .tint(Palette.accent)
                    .accessibilityLabel("Savings progress")
                    .accessibilityValue("\(Int(savingsProgress * 100)) percent")
            }

            slider
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
        }
    }

    private var inactiveGoalsGroup: some View {
        CardSurface(contentPadding: Spacing.md) {
            DisclosureGroup(isExpanded: $isInactiveExpanded) {
                VStack(spacing: Spacing.none) {
                    ForEach(Array(inactiveGoals.enumerated()), id: \.element.id) { index, goal in
                        inactiveGoalRow(goal)

                        if index < inactiveGoals.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            } label: {
                HStack {
                    Text("Inactive")
                        .prominentLabelTypography()
                        .foregroundStyle(Palette.ink)

                    Spacer()

                    Text("\(inactiveGoals.count)")
                        .rowDetailEmphasisTypography()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .tint(Palette.accent)
        }
    }

    private func inactiveGoalRow(_ goal: SavingsGoalEntity) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(goal.name)
                    .rowTitleTypography()
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: Spacing.sm)

                Text(money(goal.monthlyTarget))
                    .rowDetailEmphasisTypography()
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }

            HStack(spacing: Spacing.sm) {
                Button("Reactivate") {
                    reactivate(goal)
                }
                .buttonStyle(.bordered)
                .tint(Palette.accent)
                .frame(minHeight: 44)

                Button("Delete", role: .destructive) {
                    pendingDeletion = PendingGoalDeletion(id: goal.id, name: goal.name)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var slider: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Drag to re-plan the month")
                    .rowDetailEmphasisTypography()
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: Spacing.sm)

                Text(money(sliderTarget))
                    .rowAmountTypography()
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
            }

            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        onPreviewTarget(Self.decimalTarget(from: newValue))
                    }
                ),
                in: 0...sliderUpperBound,
                step: 50
            ) { editing in
                isDragging = editing
                if !editing {
                    sliderUpperBound = Self.upperBound(for: sliderTarget)
                    commitSliderTarget()
                }
            }
            .tint(Palette.accent)

            HStack {
                Text(money(.zero))
                Spacer()
                Text(money(Self.decimalTarget(from: sliderUpperBound)))
            }
            .captionTypography()
            .monospacedDigit()
            .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var savingsProgress: Double {
        guard projection.savingsTarget > .zero else {
            return 0
        }

        let ratio = projection.savingsCompleted / projection.savingsTarget
        return min(1, max(0, NSDecimalNumber(decimal: ratio).doubleValue))
    }

    private static func upperBound(for savingsTarget: Decimal) -> Double {
        let savingsTarget = NSDecimalNumber(decimal: savingsTarget).doubleValue
        let unroundedUpperBound = max(4_000, savingsTarget * 2)
        return (unroundedUpperBound / 50).rounded(.up) * 50
    }

    private var sliderTarget: Decimal {
        Self.decimalTarget(from: sliderValue)
    }

    private func synchronizeSlider() {
        sliderValue = NSDecimalNumber(decimal: projection.savingsTarget).doubleValue
        sliderUpperBound = Self.upperBound(for: projection.savingsTarget)
    }

    static func decimalTarget(from value: Double) -> Decimal {
        let roundedValue = value.rounded()
        guard roundedValue.isFinite else {
            return roundedValue.sign == .minus ? .zero : Decimal(Int.max)
        }
        guard roundedValue > .zero else {
            return .zero
        }
        guard roundedValue < Double(Int.max) else {
            return Decimal(Int.max)
        }

        return Decimal(Int(roundedValue))
    }

    private func commitSliderTarget() {
        guard
            let plan = plans.first,
            let stored = storedGoals.first(where: { $0.id == plan.id })
        else {
            onPreviewTarget(nil)
            return
        }

        do {
            try repository.updateSavingsGoal(
                SavingsGoalEntity(
                    id: stored.id,
                    name: stored.name,
                    targetAmount: stored.targetAmount,
                    monthlyTarget: sliderTarget,
                    currentAmount: stored.currentAmount,
                    targetDate: stored.targetDate,
                    isActive: stored.isActive
                )
            )
            projectionStore.refresh()
            onPreviewTarget(nil)
        } catch {
            synchronizeSlider()
            onPreviewTarget(nil)
            presentedError = WriteErrorPresentation(
                operation: .update,
                subject: "savings target",
                error: error
            )
        }
    }

    private var inactiveGoals: [SavingsGoalEntity] {
        storedGoals
            .filter { !$0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func reactivate(_ goal: SavingsGoalEntity) {
        do {
            try repository.updateSavingsGoal(
                SavingsGoalEntity(
                    id: goal.id,
                    name: goal.name,
                    targetAmount: goal.targetAmount,
                    monthlyTarget: goal.monthlyTarget,
                    currentAmount: goal.currentAmount,
                    targetDate: goal.targetDate,
                    isActive: true,
                    createdAt: goal.createdAt,
                    updatedAt: goal.updatedAt
                )
            )
            projectionStore.refresh()
        } catch {
            presentedError = WriteErrorPresentation(
                operation: .reactivate,
                subject: "savings goal",
                error: error
            )
        }
    }

    private func deleteInactiveGoal(id: UUID) {
        pendingDeletion = nil

        do {
            try repository.deleteSavingsGoal(id: id)
            projectionStore.refresh()
        } catch {
            presentedError = WriteErrorPresentation(
                operation: .delete,
                subject: "savings goal",
                error: error
            )
        }
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormatter.string(
            amount,
            currencyCode: appState.currencyCode,
            style: .compact
        )
    }

    private struct PendingGoalDeletion {
        let id: UUID
        let name: String
    }
}
