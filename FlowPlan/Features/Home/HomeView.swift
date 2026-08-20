import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectionStore.self) private var projectionStore

    let onSeeAllBills: () -> Void
    let onSeeAllTransactions: () -> Void

    private let now: () -> Date
    private let calendar: Calendar
    private let contentHorizontalPadding: CGFloat = 20
    private let bottomContentClearance: CGFloat = 80

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
        List {
            greetingAndMonth
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, 20)
                .homeListRow()

            if let loadErrorMessage = projectionStore.loadErrorMessage {
                staleDataBanner(loadErrorMessage)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.bottom, 20)
                    .homeListRow()
            }

            AvailableThisMonthCard(
                projection: projectionStore.projection,
                completeness: projectionStore.completeness,
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
                .padding(.top, 24)
                .padding(.bottom, 36)
                .homeListRow()
        }
        .listStyle(.plain)
        .listSectionSpacing(28)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 24, for: .scrollContent)
        .background(Palette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
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
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Typography.supporting.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface)
            .overlay {
                Rectangle().stroke(Palette.accent, lineWidth: 1)
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
