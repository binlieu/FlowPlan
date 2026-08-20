import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAllBills: () -> Void
    let onSeeAllTransactions: () -> Void

    private let contentHorizontalPadding: CGFloat = 20

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
                .padding(.bottom, 20)
                .homeListRow()

            AvailableThisMonthCard(
                projection: projectionStore.projection,
                onOpenPlan: onSeeAllBills
            )
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.bottom, 28)
            .homeListRow()

            if !isFirstRun {
                CashFlowBar(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, 28)
                    .homeListRow()

                EstimatedSavingsCard(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, 28)
                    .homeListRow()

                MonthSpendingCard(projection: projectionStore.projection)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, 28)
                    .homeListRow()
            }

            UpcomingBillsSection(onSeeAll: onSeeAllBills)

            QuickAddRow()
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 36)
                .homeListRow()
        }
        .listStyle(.plain)
        .listSectionSpacing(28)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 24, for: .scrollContent)
        .background(Palette.background)
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

    private var greetingAndMonth: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(greeting)
                .greetingTypography()
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("KNOW WHERE YOUR MONEY GOES")
                .smallCapsTypography()
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            MonthNavigationBar()
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let name = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Good morning" : "Good morning, \(name)"
    }

    private var isFirstRun: Bool {
        projectionStore.projection.completeness.hasNoPlanningInputs
    }
}

private extension View {
    func homeListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
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
