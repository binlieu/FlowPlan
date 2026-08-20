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
    let onAdd: () -> Void
    let onEdit: (SavingsPlan) -> Void
    let onPreviewTarget: (Decimal?) -> Void

    @State private var sliderValue = 0.0
    @State private var sliderUpperBound = 4_000.0
    @State private var isDragging = false
    @State private var isInactiveExpanded = false
    @State private var presentedError: PresentedError?
    @State private var pendingDeletion: PendingGoalDeletion?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(alignment: .leading, spacing: 16) {
                if let plan = plans.first {
                    goalSummary(plan)
                    slider
                } else {
                    Text("Add a savings goal to reserve money in your monthly plan.")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.hairline, lineWidth: 1)
            }

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
                title: Text("Unable to update savings goal"),
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Savings Goal")
                .sectionHeadingTypography()
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 8)

            if let plan = plans.first {
                Button("Edit") {
                    onEdit(plan)
                }
                .font(.subheadline.weight(.bold))
                .fontWidth(.condensed)
                .foregroundStyle(Palette.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            } else {
                Button("Add", action: onAdd)
                    .font(.subheadline.weight(.bold))
                    .fontWidth(.condensed)
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private func goalSummary(_ plan: SavingsPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)

                    Text("Saved this month")
                        .font(Typography.supporting)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Spacer(minLength: 12)

                Text("\(money(projection.savingsCompleted)) of \(money(projection.savingsTarget))")
                    .font(.subheadline.weight(.semibold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.trailing)
            }

            ProgressView(value: savingsProgress)
                .tint(Palette.accent)
                .accessibilityLabel("Savings progress")
                .accessibilityValue("\(Int(savingsProgress * 100)) percent")
        }
    }

    private var inactiveGoalsGroup: some View {
        DisclosureGroup(isExpanded: $isInactiveExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(inactiveGoals.enumerated()), id: \.element.id) { index, goal in
                    inactiveGoalRow(goal)

                    if index < inactiveGoals.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Inactive")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text("\(inactiveGoals.count)")
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .tint(Palette.accent)
        .padding(16)
        .background(Palette.surface)
        .overlay {
            Rectangle().stroke(Palette.hairline, lineWidth: 1)
        }
    }

    private func inactiveGoalRow(_ goal: SavingsGoalEntity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(goal.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 12)

                Text(money(goal.monthlyTarget))
                    .font(.subheadline.weight(.semibold))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }

            HStack(spacing: 12) {
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
        .padding(.vertical, 12)
    }

    private var slider: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Drag to re-plan the month")
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 12)

                Text(money(sliderTarget))
                    .font(.headline.weight(.bold))
                    .fontWidth(.condensed)
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
            .font(.caption)
            .fontWidth(.condensed)
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
            presentedError = PresentedError(
                message: "The savings target could not be saved. Please try again."
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
            presentedError = PresentedError(
                message: "The savings goal could not be reactivated. Please try again."
            )
        }
    }

    private func deleteInactiveGoal(id: UUID) {
        pendingDeletion = nil

        do {
            try repository.deleteSavingsGoal(id: id)
            projectionStore.refresh()
        } catch {
            presentedError = PresentedError(
                message: "The savings goal could not be deleted. Please try again."
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

    private struct PresentedError: Identifiable {
        let id = UUID()
        let message: String
    }

    private struct PendingGoalDeletion {
        let id: UUID
        let name: String
    }
}
