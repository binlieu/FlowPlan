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
    @State private var presentedError: PresentedError?

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
            } else {
                Button("Add", action: onAdd)
                    .font(.subheadline.weight(.bold))
                    .fontWidth(.condensed)
                    .foregroundStyle(Palette.accent)
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
                        onPreviewTarget(decimalTarget(from: newValue))
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
                Text(money(decimalTarget(from: sliderUpperBound)))
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
        decimalTarget(from: sliderValue)
    }

    private func synchronizeSlider() {
        sliderValue = NSDecimalNumber(decimal: projection.savingsTarget).doubleValue
        sliderUpperBound = Self.upperBound(for: projection.savingsTarget)
    }

    private func decimalTarget(from value: Double) -> Decimal {
        Decimal(Int(value.rounded()))
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
}
