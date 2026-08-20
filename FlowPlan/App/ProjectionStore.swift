import Foundation
import Observation
import SwiftData
import FlowPlanDomain

@Observable
@MainActor
final class ProjectionStore {
    private(set) var dataVersion = 0
    private(set) var projection: MonthlyProjection
    private(set) var currentTransactions: [TransactionSnapshot]
    private(set) var previousTransactions: [TransactionSnapshot]
    private(set) var insights: [Insight]
    private(set) var hasStartingBalance: Bool
    private(set) var isStale: Bool
    private(set) var loadError: FinanceRepositoryError?

    var completeness: ProjectionCompleteness {
        ProjectionCompleteness(
            hasStartingBalance: hasStartingBalance,
            hasPlannedIncome: projection.completeness.hasPlannedIncome,
            hasBills: projection.completeness.hasBills,
            hasSpendingBudget: projection.completeness.hasSpendingBudget,
            hasSavingsGoal: projection.completeness.hasSavingsGoal
        )
    }

    var loadErrorMessage: String? {
        guard isStale else {
            return nil
        }

        return "Your data couldn't be loaded. The figures below may be out of date."
    }

    @ObservationIgnored private let repository: FinanceRepository
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let engine: MonthlyProjectionEngine
    @ObservationIgnored private let insightsEngine: InsightsEngine
    @ObservationIgnored private var projectionInput: ProjectionInput

    init(
        repository: FinanceRepository,
        appState: AppState,
        modelContext: ModelContext,
        engine: MonthlyProjectionEngine = .init()
    ) {
        self.repository = repository
        self.appState = appState
        self.modelContext = modelContext
        self.engine = engine
        let loadedInsightsEngine = InsightsEngine()
        insightsEngine = loadedInsightsEngine

        let referenceDate = Date()
        let result = repository.projectionInputResult(
            for: appState.selectedMonth,
            referenceDate: referenceDate,
            configuration: .default
        )
        let input: ProjectionInput
        let loadedStartingBalance: Bool
        let loadedIsStale: Bool
        let loadedError: FinanceRepositoryError?
        switch (result, Self.hasStartingBalance(in: modelContext, for: appState.selectedMonth)) {
        case (.success(let loadedInput), .success(let isPresent)):
            input = loadedInput
            loadedStartingBalance = isPresent
            loadedIsStale = false
            loadedError = nil
        case (.failure(let error), _), (_, .failure(let error)):
            input = ProjectionInput(
                month: appState.selectedMonth,
                referenceDate: referenceDate,
                startingBalance: .zero,
                calendar: .current,
                configuration: .default
            )
            loadedStartingBalance = false
            loadedIsStale = true
            loadedError = error
        }

        let loadedProjection = engine.project(input)
        let loadedCurrentTransactions = loadedIsStale ? [] : input.transactions
        let loadedPreviousTransactions = loadedIsStale
            ? []
            : repository.transactions(in: appState.selectedMonth.previous)

        projectionInput = input
        projection = loadedProjection
        currentTransactions = loadedCurrentTransactions
        previousTransactions = loadedPreviousTransactions
        hasStartingBalance = loadedStartingBalance
        isStale = loadedIsStale
        loadError = loadedError
        insights = loadedIsStale
            ? []
            : loadedInsightsEngine.insights(
                for: loadedProjection,
                transactions: loadedCurrentTransactions,
                previousTransactions: loadedPreviousTransactions,
                bills: input.bills
            )

        repository.setSuccessfulWriteHandler { [weak self] in
            self?.dataVersion += 1
        }
    }

    func refresh() {
        let result = repository.projectionInputResult(
            for: appState.selectedMonth,
            referenceDate: Date(),
            configuration: .default
        )

        switch (result, Self.hasStartingBalance(in: modelContext, for: appState.selectedMonth)) {
        case (.success(let input), .success(let isPresent)):
            let refreshedProjection = engine.project(input)
            let refreshedPreviousTransactions = repository.transactions(
                in: appState.selectedMonth.previous
            )

            projectionInput = input
            projection = refreshedProjection
            currentTransactions = input.transactions
            previousTransactions = refreshedPreviousTransactions
            insights = insightsEngine.insights(
                for: refreshedProjection,
                transactions: input.transactions,
                previousTransactions: refreshedPreviousTransactions,
                bills: input.bills
            )
            hasStartingBalance = isPresent
            isStale = false
            loadError = nil
        case (.failure(let error), _), (_, .failure(let error)):
            isStale = true
            loadError = error
        }
    }

    func simulate(_ scenario: WhatIfScenario) -> WhatIfResult {
        engine.simulate(scenario, on: projectionInput)
    }

    private static func hasStartingBalance(
        in modelContext: ModelContext,
        for month: MonthKey
    ) -> Result<Bool, FinanceRepositoryError> {
        let year = month.year
        let monthNumber = month.month
        let predicate = #Predicate<MonthSettingsEntity> { settings in
            settings.year == year && settings.month == monthNumber
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let settings = try modelContext.fetch(descriptor)
            return .success(!settings.isEmpty)
        } catch {
            return .failure(.dataLoadFailed)
        }
    }
}
