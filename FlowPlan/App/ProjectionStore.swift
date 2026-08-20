import Foundation
import Observation
import FlowPlanDomain

@Observable
@MainActor
final class ProjectionStore {
    private(set) var projection: MonthlyProjection
    private(set) var isStale: Bool
    private(set) var loadError: FinanceRepositoryError?

    var loadErrorMessage: String? {
        guard isStale else {
            return nil
        }

        return "Your data couldn't be loaded. The figures below may be out of date."
    }

    @ObservationIgnored private let repository: FinanceRepository
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let engine: MonthlyProjectionEngine
    @ObservationIgnored private var projectionInput: ProjectionInput

    init(
        repository: FinanceRepository,
        appState: AppState,
        engine: MonthlyProjectionEngine = .init()
    ) {
        self.repository = repository
        self.appState = appState
        self.engine = engine

        let referenceDate = Date()
        let result = repository.projectionInputResult(
            for: appState.selectedMonth,
            referenceDate: referenceDate,
            configuration: .default
        )
        let input: ProjectionInput
        switch result {
        case .success(let loadedInput):
            input = loadedInput
            isStale = false
            loadError = nil
        case .failure(let error):
            input = ProjectionInput(
                month: appState.selectedMonth,
                referenceDate: referenceDate,
                startingBalance: .zero,
                calendar: .current,
                configuration: .default
            )
            isStale = true
            loadError = error
        }
        projectionInput = input
        projection = engine.project(input)
    }

    func refresh() {
        let result = repository.projectionInputResult(
            for: appState.selectedMonth,
            referenceDate: Date(),
            configuration: .default
        )

        switch result {
        case .success(let input):
            projectionInput = input
            projection = engine.project(input)
            isStale = false
            loadError = nil
        case .failure(let error):
            isStale = true
            loadError = error
        }
    }

    func simulate(_ scenario: WhatIfScenario) -> WhatIfResult {
        engine.simulate(scenario, on: projectionInput)
    }
}
