import OSLog
import SwiftData
import SwiftUI

@main
@MainActor
struct FlowPlanApp: App {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FlowPlan",
        category: "AppLifecycle"
    )

    private let modelContainer: ModelContainer
    @State private var appState: AppState
    @State private var repository: FinanceRepository
    @State private var projectionStore: ProjectionStore

    init() {
        let container = PersistenceController.shared
        let state = AppState()
        let context = container.mainContext

        if state.isSampleDataEnabled, !SampleData.isSeeded(context) {
            do {
                try SampleData.seed(into: context, calendar: .current)
            } catch {
                Self.logger.error("Sample data seeding failed.")
            }
        }

        let repository = FinanceRepository(context: context)
        let projectionStore = ProjectionStore(repository: repository, appState: state)

        modelContainer = container
        _appState = State(initialValue: state)
        _repository = State(initialValue: repository)
        _projectionStore = State(initialValue: projectionStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(repository)
                .environment(projectionStore)
        }
        .modelContainer(modelContainer)
    }
}
