import SwiftUI
import FlowPlanDomain

struct ProjectionHeroCard: View {
    @Environment(AppState.self) private var appState

    let projection: MonthlyProjection
    let onOpenPlan: () -> Void

    @State private var isShowingBreakdown = false

    init(
        projection: MonthlyProjection,
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        Group {
            if projection.completeness.hasNoPlanningInputs {
                firstRunCard
            } else {
                projectionButton
            }
        }
    }

    private var projectionButton: some View {
        Button {
            isShowingBreakdown = true
        } label: {
            projectionCardBody
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $isShowingBreakdown) {
            // TODO(spec-04): ProjectionDetailView
            Text("Breakdown")
                .navigationTitle("Projection Breakdown")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows how this was calculated")
    }

    private var projectionCardBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PROJECTED MONTH END")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    AmountText(
                        amount: projection.projectedEndOfMonthBalance,
                        style: .hero,
                        emphasiseNegative: true
                    )
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Text(interpretation)
                .font(.body)
                .foregroundStyle(.primary)

            Label(directionText, systemImage: directionSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(directionColor)

            ProjectionStatusBadge(status: projection.status)

            if let completenessNote {
                Label(completenessNote, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(heroBackground, in: RoundedRectangle(cornerRadius: 24))
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }

    private var firstRunCard: some View {
        EmptyStateView(
            symbol: "calendar.badge.plus",
            title: "No plan for \(monthName) yet",
            message: "Add your expected income to see where the month will land.",
            actionTitle: "Go to Plan",
            action: onOpenPlan
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(heroBackground, in: RoundedRectangle(cornerRadius: 24))
    }

    private var heroBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.16),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var monthName: String {
        projection.month
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide))
    }

    private var interpretation: String {
        switch projection.status {
        case .healthy:
            return "You're projected to finish \(monthName) with \(projectedBalanceString) remaining."
        case .tight:
            return "You're projected to finish \(monthName) with only \(projectedBalanceString) remaining."
        case .negative:
            return "You're projected to be \(shortfallString) short this month."
        case .aheadOfPlan:
            return "You're currently \(varianceMagnitudeString) ahead of your monthly plan."
        }
    }

    private var accessibleInterpretation: String {
        switch projection.status {
        case .healthy:
            return "You're projected to finish \(monthName) with \(accessibleProjectedBalance) remaining."
        case .tight:
            return "You're projected to finish \(monthName) with only \(accessibleProjectedBalance) remaining."
        case .negative:
            return "You're projected to be \(accessibleShortfall) short this month."
        case .aheadOfPlan:
            return "You're currently \(accessibleVarianceMagnitude) ahead of your monthly plan."
        }
    }

    private var projectedBalanceString: String {
        MoneyFormatter.string(
            projection.projectedEndOfMonthBalance,
            currencyCode: appState.currencyCode
        )
    }

    private var shortfallString: String {
        MoneyFormatter.string(
            magnitude(of: projection.projectedEndOfMonthBalance),
            currencyCode: appState.currencyCode
        )
    }

    private var varianceMagnitudeString: String {
        MoneyFormatter.string(
            magnitude(of: projection.varianceVsPlan),
            currencyCode: appState.currencyCode
        )
    }

    private var accessibleProjectedBalance: String {
        MoneyFormatter.accessibleString(
            projection.projectedEndOfMonthBalance,
            currencyCode: appState.currencyCode
        )
    }

    private var accessibleShortfall: String {
        MoneyFormatter.accessibleString(
            magnitude(of: projection.projectedEndOfMonthBalance),
            currencyCode: appState.currencyCode
        )
    }

    private var accessibleVarianceMagnitude: String {
        MoneyFormatter.accessibleString(
            magnitude(of: projection.varianceVsPlan),
            currencyCode: appState.currencyCode
        )
    }

    private var directionText: String {
        let amount = MoneyFormatter.string(
            projection.varianceVsPlan,
            currencyCode: appState.currencyCode,
            signed: true
        )
        return "\(amount) vs your original plan"
    }

    private var directionSymbol: String {
        if projection.varianceVsPlan > .zero {
            return "arrow.up.right"
        }
        if projection.varianceVsPlan < .zero {
            return "arrow.down.right"
        }
        return "equal"
    }

    private var directionColor: Color {
        projection.status == .negative ? .red : .secondary
    }

    private var completenessNote: String? {
        guard !projection.completeness.isComplete else {
            return nil
        }

        let descriptions = projection.completeness.missing.map(missingDescription)
        let missingList = ListFormatter.localizedString(byJoining: descriptions)
        return "Projection may be incomplete: \(missingList)."
    }

    private var accessibilityLabel: String {
        "Projected month end, \(accessibleProjectedBalance). \(accessibleInterpretation)"
    }

    private func magnitude(of amount: Decimal) -> Decimal {
        amount < .zero ? -amount : amount
    }

    private func missingDescription(_ item: String) -> String {
        switch item {
        case "Starting balance":
            return "no starting balance set"
        case "Planned income":
            return "no income planned for this month"
        case "Bills":
            return "no bills planned for this month"
        case "Spending budget":
            return "no spending budget set"
        case "Savings goal":
            return "no savings goal set"
        default:
            return item.lowercased()
        }
    }
}

extension ProjectionCompleteness {
    var hasNoPlanningInputs: Bool {
        !hasStartingBalance
            && !hasPlannedIncome
            && !hasBills
            && !hasSpendingBudget
            && !hasSavingsGoal
    }
}

#if DEBUG
#Preview("All statuses — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .healthy))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .tight))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .negative))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .aheadOfPlan))
                }
                .padding()
            }
        }
    }
}

#Preview("All statuses — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .healthy))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .tight))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .negative))
                    ProjectionHeroCard(projection: FlowPlanPreviewData.projection(status: .aheadOfPlan))
                }
                .padding()
            }
        }
    }
}

#Preview("First Run — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            ProjectionHeroCard(projection: ProjectionHeroCardPreviewData.firstRun)
                .padding()
        }
    }
}

#Preview("Healthy Badge + Negative Variance") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            ProjectionHeroCard(
                projection: ProjectionHeroCardPreviewData.healthyWithNegativeVariance
            )
            .padding()
        }
    }
}

private enum ProjectionHeroCardPreviewData {
    static let firstRun = MonthlyProjection(
        month: FlowPlanPreviewData.month,
        totalExpectedIncome: .zero,
        incomeReceived: .zero,
        remainingExpectedIncome: .zero,
        expensesPaid: .zero,
        remainingBills: .zero,
        billsPaid: .zero,
        projectedVariableSpending: .zero,
        actualVariableSpending: .zero,
        remainingVariableSpending: .zero,
        savingsCompleted: .zero,
        remainingSavingsGoal: .zero,
        savingsTarget: .zero,
        startingBalance: .zero,
        currentAvailableBalance: .zero,
        projectedEndOfMonthBalance: .zero,
        plannedEndOfMonthBalance: .zero,
        varianceVsPlan: .zero,
        spendableRemaining: .zero,
        dailySafeToSpend: .zero,
        daysRemaining: 31,
        daysInMonth: 31,
        savingsRate: .zero,
        status: .tight,
        completeness: ProjectionCompleteness(
            hasStartingBalance: false,
            hasPlannedIncome: false,
            hasBills: false,
            hasSpendingBudget: false,
            hasSavingsGoal: false
        ),
        breakdown: []
    )

    static let healthyWithNegativeVariance = MonthlyProjection(
        month: FlowPlanPreviewData.month,
        totalExpectedIncome: 6_500,
        incomeReceived: 6_500,
        remainingExpectedIncome: .zero,
        expensesPaid: 3_120,
        remainingBills: 680,
        billsPaid: 1_850,
        projectedVariableSpending: 1_250,
        actualVariableSpending: 1_270,
        remainingVariableSpending: 730,
        savingsCompleted: 750,
        remainingSavingsGoal: 1_250,
        savingsTarget: 2_000,
        startingBalance: 2_400,
        currentAvailableBalance: 3_030,
        projectedEndOfMonthBalance: 1_420,
        plannedEndOfMonthBalance: 1_820,
        varianceVsPlan: -400,
        spendableRemaining: 2_350,
        dailySafeToSpend: 82,
        daysRemaining: 15,
        daysInMonth: 31,
        savingsRate: 0.31,
        status: .healthy,
        completeness: ProjectionCompleteness(
            hasStartingBalance: true,
            hasPlannedIncome: true,
            hasBills: true,
            hasSpendingBudget: true,
            hasSavingsGoal: true
        ),
        breakdown: []
    )
}
#endif
