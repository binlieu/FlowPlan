import Foundation
import Observation
import LieuFlowDomain

@Observable
@MainActor
final class ProjectionStore {
    private(set) var projection: MonthlyProjection

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

        let input = repository.projectionInput(
            for: appState.selectedMonth,
            referenceDate: Date(),
            configuration: .default
        )
        projectionInput = input
        projection = engine.project(input)
    }

    func refresh() {
        let input = repository.projectionInput(
            for: appState.selectedMonth,
            referenceDate: Date(),
            configuration: .default
        )
        projectionInput = input
        projection = engine.project(input)
    }

    func simulate(_ scenario: WhatIfScenario) -> WhatIfResult {
        engine.simulate(scenario, on: projectionInput)
    }
}
