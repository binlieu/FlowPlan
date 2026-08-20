import SwiftUI
import FlowPlanDomain

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSeeAllBills: () -> Void
    let onSeeAllTransactions: () -> Void

    @State private var isPresentingAddTransaction = false

    private let contentHorizontalPadding: CGFloat = 20
    private let bottomContentClearance: CGFloat = 80

    init(
        onSeeAllBills: @escaping () -> Void = {},
        onSeeAllTransactions: @escaping () -> Void = {}
    ) {
        self.onSeeAllBills = onSeeAllBills
        self.onSeeAllTransactions = onSeeAllTransactions
    }

    var body: some View {
        List {
            greetingAndMonth
                .padding(.horizontal, contentHorizontalPadding)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ProjectionHeroCard(
                projection: projectionStore.projection,
                onOpenPlan: onSeeAllBills
            )
                .padding(.horizontal, contentHorizontalPadding)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            dashboardStats
                .padding(.horizontal, contentHorizontalPadding)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if shouldShowIncomePlanPrompt {
                EmptyStateView(
                    symbol: "dollarsign.circle",
                    title: "Income plan needed",
                    message: "Add your expected income to improve your month-end projection."
                )
                .listRowSeparator(.hidden)
            }

            SafeToSpendCard(projection: projectionStore.projection)
                .padding(.horizontal, contentHorizontalPadding)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            UpcomingBillsSection(onSeeAll: onSeeAllBills)
            RecentTransactionsSection(onSeeAll: onSeeAllTransactions)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: bottomContentClearance)
                .accessibilityHidden(true)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingAddTransaction = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add transaction")
            }
        }
        .sheet(isPresented: $isPresentingAddTransaction) {
            AddTransactionView()
        }
        .refreshable {
            projectionStore.refresh()
        }
        .onChange(of: appState.selectedMonth) {
            projectionStore.refresh()
        }
    }

    private var greetingAndMonth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(greeting), \(appState.userName)")
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            MonthNavigationBar()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dashboardStats: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            StatTile(
                title: "Income",
                symbol: "arrow.down.circle",
                amount: projectionStore.projection.totalExpectedIncome
            )
            StatTile(
                title: "Spent",
                symbol: "arrow.up.circle",
                amount: projectionStore.projection.expensesPaid
            )
            StatTile(
                title: "Bills Remaining",
                symbol: "calendar.badge.clock",
                amount: projectionStore.projection.remainingBills
            )
            StatTile(
                title: "Savings",
                symbol: "banknote",
                amount: projectionStore.projection.savingsCompleted,
                secondaryAmount: projectionStore.projection.savingsTarget
            )
        }
    }

    private var gridColumns: [GridItem] {
        let minimumWidth: CGFloat = dynamicTypeSize.isAccessibilitySize ? 240 : 145
        return [GridItem(.adaptive(minimum: minimumWidth), spacing: 12)]
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var shouldShowIncomePlanPrompt: Bool {
        !projectionStore.projection.completeness.hasPlannedIncome
            && !projectionStore.projection.completeness.hasNoPlanningInputs
    }
}

#if DEBUG
#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Long Name — Smallest Dynamic Type") {
    FlowPlanPreviewHost(colorScheme: .light) {
        HomeViewPreview(userName: "Alexandria Catherine Montgomery-Wellington")
    }
    .dynamicTypeSize(.xSmall)
}

#Preview("Long Name — Largest Dynamic Type") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        HomeViewPreview(userName: "Alexandria Catherine Montgomery-Wellington")
    }
    .dynamicTypeSize(.accessibility5)
}

@MainActor
private struct HomeViewPreview: View {
    @Environment(AppState.self) private var appState

    let userName: String

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .onAppear {
            appState.userName = userName
        }
    }
}
#endif
