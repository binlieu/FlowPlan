import Foundation
import OSLog
import SwiftData

enum PersistenceController {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FlowPlan",
        category: "Persistence"
    )

    static let schema = Schema([
        TransactionEntity.self,
        IncomeSourceEntity.self,
        RecurringBillEntity.self,
        BudgetEntity.self,
        SavingsGoalEntity.self,
        MonthSettingsEntity.self
    ])

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration("FlowPlan", schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Persistent store unavailable; using an in-memory store.")

            do {
                return try inMemory()
            } catch {
                preconditionFailure("Unable to initialize local persistence.")
            }
        }
    }()

    /// A fresh in-memory container for tests and previews.
    ///
    /// The configuration is named per container so concurrent containers cannot share a store
    /// identity. That matters because the entities carry uniqueness constraints —
    /// `MonthSettingsEntity` is unique on (year, month) and every test uses the same month — so
    /// any store sharing between two supposedly independent containers would surface as a
    /// constraint violation rather than as an obviously wrong result.
    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "InMemory-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
