import SwiftData
import SwiftUI
import FlowPlanDomain

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    @State private var selectedTab = AppTab.home
    private let biometricAvailability = BiometricAuthenticator().canEvaluate()
    @State private var biometricGate = BiometricGate(
        isEnabled: UserDefaults.standard.bool(forKey: "isFaceIDEnabled"),
        autoLockInterval: AutoLockInterval.storedValue(in: .standard)
    )
    @AppStorage(AutoLockInterval.storageKey)
    private var autoLockInterval: AutoLockInterval = .oneMinute

    var body: some View {
        ZStack {
            tabs
                .accessibilityHidden(isAppLocked)

            if isAppLocked {
                AppLockView(gate: biometricGate)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(appState.appearancePreference.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: biometricGate.isLocked)
        .onAppear {
            biometricGate.setAutoLockInterval(autoLockInterval)
            if appState.isFaceIDEnabled, !isFaceIDAvailable {
                appState.isFaceIDEnabled = false
            } else if appState.isFaceIDEnabled != biometricGate.isEnabled {
                biometricGate.setEnabled(appState.isFaceIDEnabled)
            }
        }
        .onChange(of: appState.isFaceIDEnabled) {
            biometricGate.setEnabled(appState.isFaceIDEnabled)
        }
        .onChange(of: autoLockInterval) {
            biometricGate.setAutoLockInterval(autoLockInterval)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                biometricGate.appDidBecomeActive()
            case .background:
                biometricGate.appDidEnterBackground()
            case .inactive:
                // Transient system UI — the Face ID prompt itself, a notification banner,
                // Control Centre, the app switcher preview. The user has not left the app,
                // so locking here made every successful unlock re-lock instantly.
                break
            @unknown default:
                break
            }
        }
    }

    private var isFaceIDAvailable: Bool {
        biometricAvailability.isAvailable && biometricAvailability.biometry == .faceID
    }

    private var isAppLocked: Bool {
        appState.isFaceIDEnabled && isFaceIDAvailable && biometricGate.isLocked
    }

    private var tabs: some View {
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
                PlanView()
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("PLAN", systemImage: "list.clipboard") }
            .tag(AppTab.plan)

            NavigationStack {
                InsightsView()
            }
            .environment(appState)
            .environment(repository)
            .environment(projectionStore)
            .tabItem { Label("INSIGHTS", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.insights)

            NavigationStack {
                SettingsView()
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

    private enum AppTab: Hashable {
        case home
        case transactions
        case plan
        case insights
        case settings
    }
}

private extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
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

        guard let defaults = UserDefaults(
            suiteName: "FlowPlanPreviews.\(UUID().uuidString)"
        ) else {
            preconditionFailure("Unable to create isolated preview preferences.")
        }
        let state = AppState(
            selectedMonth: FlowPlanPreviewData.month,
            calendar: FlowPlanPreviewData.calendar,
            userDefaults: defaults,
            now: { FlowPlanPreviewData.referenceDate }
        )
        let repository = FinanceRepository(
            context: container.mainContext,
            calendar: FlowPlanPreviewData.calendar,
            userDefaults: defaults,
            now: { FlowPlanPreviewData.referenceDate }
        )
        let projectionStore = ProjectionStore(
            repository: repository,
            appState: state,
            modelContext: container.mainContext
        )

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
            plannedIncomeTotal: 6_500,
            plannedBillsTotal: 2_530,
            plannedSpendingTotal: 3_000,
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
