import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(FinanceRepository.self) private var repository
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAllBills: () -> Void
    let onSeeAllTransactions: () -> Void

    private let now: () -> Date
    private let calendar: Calendar
    private let contentHorizontalPadding: CGFloat = Spacing.lg
    private let quickAddTopPadding: CGFloat = Spacing.lg
    private let bottomContentClearance: CGFloat = Spacing.xl

    init(
        onSeeAllBills: @escaping () -> Void = {},
        onSeeAllTransactions: @escaping () -> Void = {},
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.onSeeAllBills = onSeeAllBills
        self.onSeeAllTransactions = onSeeAllTransactions
        self.calendar = calendar
        self.now = now
    }

    var body: some View {
        let _ = projectionStore.dataVersion
        let hasOrphanedDebt = !OrphanedDebtDetector.orphanedDebts(
            in: repository.debts(),
            bills: repository.bills(),
            calendar: calendar
        ).isEmpty

        List {
            VStack(alignment: .leading, spacing: Spacing.none) {
                ScreenHeader(
                    title: greeting,
                    subtitle: "KNOW WHERE YOUR MONEY GOES"
                )

                MonthNavigationBar()
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, Spacing.lg)
            }
            .padding(.bottom, Spacing.lg)
            .homeListRow()

            if let loadErrorMessage = projectionStore.loadErrorMessage {
                staleDataBanner(loadErrorMessage)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, Spacing.lg)
                    .homeListRow()
            }

            AvailableThisMonthCard(
                projection: projectionStore.projection,
                completeness: projectionStore.completeness,
                hasOrphanedDebt: hasOrphanedDebt,
                onOpenPlan: onSeeAllBills
            )
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.bottom, Spacing.xl)
            .homeListRow()

            if !isFirstRun {
                CashFlowBar(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                    .homeListRow()

                EstimatedSavingsCard(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                    .homeListRow()

                MonthSpendingCard(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                    .homeListRow()
            }

            ExpectedIncomeSection(
                onSeeAll: onSeeAllBills,
                calendar: calendar,
                now: now
            )

            UpcomingBillsSection(
                onSeeAll: onSeeAllBills,
                calendar: calendar,
                now: now
            )

            QuickAddRow()
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, quickAddTopPadding)
                .padding(.bottom, Spacing.xl)
                .homeListRow()
        }
        .listStyle(.plain)
        .listSectionSpacing(Spacing.xl)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, Spacing.none, for: .scrollContent)
        .background(Palette.background)
        .safeAreaInset(edge: .bottom, spacing: Spacing.none) {
            Palette.clear
                .frame(height: bottomContentClearance)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Palette.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            projectionStore.refresh()
        }
        .onChange(of: appState.selectedMonth) {
            projectionStore.refresh()
        }
    }

    private var greeting: String {
        Self.greeting(
            name: appState.userName,
            at: now(),
            calendar: calendar
        )
    }

    private var isFirstRun: Bool {
        projectionStore.completeness.hasNoPlanningInputs
    }

    private func staleDataBanner(_ message: String) -> some View {
        CardSurface(contentPadding: Spacing.md) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .rowDetailEmphasisTypography()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
            .accessibilityLabel("Data load warning. \(message)")
    }

    static func greeting(name: String, at date: Date, calendar: Calendar) -> String {
        let salutation: String
        switch calendar.component(.hour, from: date) {
        case 0..<12:
            salutation = "Good morning"
        case 12..<17:
            salutation = "Good afternoon"
        default:
            salutation = "Good evening"
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? salutation : "\(salutation), \(trimmedName)"
    }
}

private extension View {
    func homeListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Palette.clear)
            .listRowSeparator(.hidden)
    }
}

#if DEBUG
#Preview("Home — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Home — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Home — Empty First Run") {
    FlowPlanPreviewHost(colorScheme: .light, seedSampleData: false) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("Home — Largest Dynamic Type") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            HomeView()
        }
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
