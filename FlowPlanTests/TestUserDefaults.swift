import Foundation
import Testing

func isolatedTestUserDefaults(
    suitePrefix: String = "FlowPlanTests"
) throws -> UserDefaults {
    let suiteName = "\(suitePrefix).\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
