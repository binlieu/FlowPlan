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

    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
