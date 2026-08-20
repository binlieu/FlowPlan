import SwiftUI
import FlowPlanDomain

struct PlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var presentedEditor: PresentedEditor?
    @State private var previewProjection: MonthlyProjection?
    @State private var presentedError: WriteErrorPresentation?

    var body: some View {
        // Repository fetches return domain values. Tracking the write token makes SwiftUI rerun
        // these fetches even when a successful write leaves the projection unchanged.
        let _ = projectionStore.dataVersion
        let bills = repository.bills()
        let debts = repository.debts()
        let projection = projectionForDisplay

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                ScreenHeader(title: "Plan", subtitle: selectedMonthTitle)

                Group {
                    StartingBalanceSection()

                    PlanExpectedIncomeSection(
                        sources: repository.incomeSources(),
                        plannedTotal: projection.plannedIncomeTotal,
                        onAdd: { presentedEditor = .newIncome },
                        onEdit: { presentedEditor = .income($0) }
                    )

                    MonthlyBillsSection(
                        bills: bills,
                        plannedTotal: Self.monthlyBillsTotal(for: projection),
                        onAdd: { presentedEditor = .newBill },
                        onEdit: { presentedEditor = .bill($0) }
                    )

                    DebtSection(
                        debts: debts,
                        bills: bills,
                        originalBalances: repository.debtOriginalBalances(),
                        outsideBillsTotal: projection.debtPaymentsDue,
                        onAdd: { presentedEditor = .newDebt },
                        onEdit: { presentedEditor = .debt($0) },
                        onCountSeparately: countSeparately
                    )

                    SpendingBudgetSection(
                        budgets: repository.budgets(for: appState.selectedMonth),
                        transactions: repository.transactions(in: appState.selectedMonth),
                        plannedTotal: Self.spendingBudgetTotal(for: projection),
                        onAdd: { presentedEditor = .newBudget },
                        onEdit: { presentedEditor = .budget($0) }
                    )

                    SavingsGoalSection(
                        plans: repository.savingsPlans(),
                        projection: projection,
                        plannedTotal: Self.savingsGoalTotal(for: projection),
                        onAdd: { presentedEditor = .newSavingsGoal },
                        onEdit: { presentedEditor = .savingsGoal($0) },
                        onPreviewTarget: previewSavingsTarget
                    )

                    NavigationLink {
                        ProjectionDetailView(projection: projection)
                    } label: {
                        MonthlyProjectionCard(projection: projection)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens projection details")
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 100)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            previewProjection = nil
            projectionStore.refresh()
        }
        .onChange(of: appState.selectedMonth) {
            previewProjection = nil
            projectionStore.refresh()
        }
        .sheet(item: $presentedEditor) { editor in
            editorView(editor)
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var selectedMonthTitle: String {
        appState.selectedMonth
            .startDate(calendar: .current)
            .formatted(.dateTime.month(.wide).year())
            .uppercased()
    }

    private var projectionForDisplay: MonthlyProjection {
        previewProjection ?? projectionStore.projection
    }

    static func monthlyBillsTotal(for projection: MonthlyProjection) -> Decimal {
        projection.plannedBillsTotal
    }

    static func spendingBudgetTotal(for projection: MonthlyProjection) -> Decimal {
        projection.plannedSpendingTotal
    }

    static func savingsGoalTotal(for projection: MonthlyProjection) -> Decimal {
        projection.savingsTarget
    }

    @ViewBuilder
    private func editorView(_ editor: PresentedEditor) -> some View {
        switch editor {
        case .newIncome:
            EditIncomeView()
        case .income(let source):
            EditIncomeView(source: source)
        case .newBill:
            EditBillView()
        case .bill(let bill):
            EditBillView(bill: bill)
        case .newDebt:
            EditDebtView()
        case .debt(let debt):
            EditDebtView(debt: debt)
        case .newBudget:
            EditBudgetView()
        case .budget(let budget):
            EditBudgetView(budget: budget)
        case .newSavingsGoal:
            EditSavingsGoalView()
        case .savingsGoal(let plan):
            EditSavingsGoalView(plan: plan)
        }
    }

    private func previewSavingsTarget(_ target: Decimal?) {
        guard let target else {
            previewProjection = nil
            return
        }

        previewProjection = projectionStore.simulate(
            WhatIfScenario(savingsTargetOverride: target)
        ).simulated
    }

    private func countSeparately(_ debt: Debt) {
        do {
            try repository.setDebtPaidThroughBills(
                id: debt.id,
                isPaidThroughBills: false
            )
            projectionStore.refresh()
        } catch {
            presentedError = WriteErrorPresentation(
                operation: .update,
                subject: "debt",
                error: error,
                guidance: "The payment is still marked as paid through Monthly Bills. Please try again."
            )
        }
    }

    private enum PresentedEditor: Identifiable {
        case newIncome
        case income(PlannedIncome)
        case newBill
        case bill(PlannedBill)
        case newDebt
        case debt(Debt)
        case newBudget
        case budget(BudgetAllocation)
        case newSavingsGoal
        case savingsGoal(SavingsPlan)

        var id: String {
            switch self {
            case .newIncome:
                "new-income"
            case .income(let source):
                "income-\(source.id.uuidString)"
            case .newBill:
                "new-bill"
            case .bill(let bill):
                "bill-\(bill.id.uuidString)"
            case .newDebt:
                "new-debt"
            case .debt(let debt):
                "debt-\(debt.id.uuidString)"
            case .newBudget:
                "new-budget"
            case .budget(let budget):
                "budget-\(budget.id.uuidString)"
            case .newSavingsGoal:
                "new-savings-goal"
            case .savingsGoal(let plan):
                "savings-goal-\(plan.id.uuidString)"
            }
        }
    }
}

#if DEBUG
#Preview("Plan — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            PlanView()
        }
    }
}

#Preview("Plan — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            PlanView()
        }
    }
}

#Preview("Plan — Empty") {
    FlowPlanPreviewHost(seedSampleData: false) {
        NavigationStack {
            PlanView()
        }
    }
}
#endif
