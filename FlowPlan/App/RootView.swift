import SwiftData
import SwiftUI
import FlowPlanDomain

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    onSeeAllBills: { selectedTab = .plan },
                    onSeeAllTransactions: { selectedTab = .transactions }
                )
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("HOME", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack {
                TransactionsView()
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("ACTIVITY", systemImage: "arrow.left.arrow.right") }
            .tag(AppTab.transactions)

            NavigationStack {
                placeholder(
                    symbol: "list.clipboard",
                    title: "Plan",
                    message: "Planning tools are coming in a later step."
                )
                .navigationTitle("Plan")
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("PLAN", systemImage: "list.clipboard") }
            .tag(AppTab.plan)

            NavigationStack {
                placeholder(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Insights",
                    message: "Insights are coming in a later step."
                )
                .navigationTitle("Insights")
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("INSIGHTS", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.insights)

            NavigationStack {
                placeholder(
                    symbol: "slider.horizontal.3",
                    title: "Settings",
                    message: "Settings are coming in a later step."
                )
                .navigationTitle("Settings")
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("SETTINGS", systemImage: "slider.horizontal.3") }
            .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .toolbarBackground(Palette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private func placeholder(symbol: String, title: String, message: String) -> some View {
        EmptyStateView(symbol: symbol, title: title, message: message)
    }

    private enum AppTab: Hashable {
        case home
        case transactions
        case plan
        case insights
        case settings
    }
}

#if DEBUG
@MainActor
struct FlowPlanPreviewHost<Content: View>: View {
    private let modelContainer: ModelContainer
    private let colorScheme: ColorScheme?
    private let content: Content

    @State private var appState: AppState
    @State private var repository: FinanceRepository
    @State private var projectionStore: ProjectionStore

    init(
        colorScheme: ColorScheme? = nil,
        seedSampleData: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        let container: ModelContainer
        do {
            container = try PersistenceController.inMemory()
            if seedSampleData {
                try SampleData.seed(into: container.mainContext, calendar: FlowPlanPreviewData.calendar)
            }
        } catch {
            preconditionFailure("Unable to build preview data: \(error.localizedDescription)")
        }

        let defaults = UserDefaults(
            suiteName: "FlowPlanPreviews.\(UUID().uuidString)"
        ) ?? .standard
        let state = AppState(
            selectedMonth: FlowPlanPreviewData.month,
            calendar: FlowPlanPreviewData.calendar,
            userDefaults: defaults,
            now: { FlowPlanPreviewData.referenceDate }
        )
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: FlowPlanPreviewData.calendar,
            now: { FlowPlanPreviewData.referenceDate }
        )
        let projectionStore = ProjectionStore(repository: repository, appState: state)

        modelContainer = container
        self.colorScheme = colorScheme
        self.content = content()
        _appState = State(initialValue: state)
        _repository = State(initialValue: repository)
        _projectionStore = State(initialValue: projectionStore)
    }

    var body: some View {
        content
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .modelContainer(modelContainer)
            .preferredColorScheme(colorScheme)
    }
}

enum FlowPlanPreviewData {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static let month = MonthKey(year: 2026, month: 8)
    static let referenceDate = date(day: 17)

    static func projection(status: ProjectionStatus = .healthy) -> MonthlyProjection {
        let projectedBalance: Decimal
        let plannedBalance: Decimal
        let variance: Decimal

        switch status {
        case .healthy:
            projectedBalance = 1_420
            plannedBalance = 1_370
            variance = 50
        case .tight:
            projectedBalance = 180
            plannedBalance = 200
            variance = -20
        case .negative:
            projectedBalance = -420
            plannedBalance = 180
            variance = -600
        case .aheadOfPlan:
            projectedBalance = 2_620
            plannedBalance = 2_000
            variance = 620
        }

        return MonthlyProjection(
            month: month,
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
            projectedEndOfMonthBalance: projectedBalance,
            plannedEndOfMonthBalance: plannedBalance,
            varianceVsPlan: variance,
            spendableRemaining: 2_350,
            dailySafeToSpend: 82,
            daysRemaining: 15,
            daysInMonth: 31,
            savingsRate: 0.31,
            status: status,
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

    private static func date(day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }
}

#Preview("Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        RootView()
    }
}

#Preview("Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        RootView()
    }
}
#endif
