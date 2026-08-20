# Codex task spec — 07 — Insights, Settings and Face ID

## Goal
Close the MVP: lightweight deterministic insights, real preferences, and an optional Face ID lock.

## Scope — touch ONLY these
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/InsightsEngine.swift` (create)
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/Insight.swift` (create)
- `Packages/FlowPlanDomain/Tests/FlowPlanDomainTests/InsightsEngineTests.swift` (create)
- `FlowPlan/Features/Insights/InsightsView.swift` (create)
- `FlowPlan/Features/Insights/SpendingByCategoryChart.swift` (create)
- `FlowPlan/Features/Insights/IncomeVsExpensesChart.swift` (create)
- `FlowPlan/Features/Insights/SmartInsightsSection.swift` (create)
- `FlowPlan/Features/Settings/SettingsView.swift` (create)
- `FlowPlan/Features/Settings/CategoriesSettingsView.swift` (create)
- `FlowPlan/Features/Settings/DataSettingsView.swift` (create)
- `FlowPlan/App/AppLockView.swift` (create)
- `FlowPlan/App/BiometricAuthenticator.swift` (create)
- `FlowPlan/App/RootView.swift` (edit: wire Insights and Settings tabs, and the lock gate)
- `FlowPlanTests/BiometricGateTests.swift` (create)

Do NOT modify the projection engine, `FlowPlan/Data/**`, or anything under `Features/Home`,
`Features/Projection`, `Features/Transactions`, `Features/Plan`.

## What to do

### `InsightsEngine` — still pure Foundation
Same purity rule as the rest of `FlowPlanDomain`: `Foundation` only, no `Date()`, all `Sendable`.

```swift
public struct Insight: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case spending, savings, subscriptions, projection, income }
    public let id: String
    public let kind: Kind
    public let message: String       // factual, never judgemental
    public let symbolName: String    // SF Symbol name, chosen by the domain so UI stays dumb
}

public struct InsightsEngine: Sendable {
    public init()
    public func insights(for projection: MonthlyProjection,
                         previous: MonthlyProjection?,
                         transactions: [TransactionSnapshot],
                         previousTransactions: [TransactionSnapshot],
                         bills: [PlannedBill]) -> [Insight]
}
```

Deterministic rules only — **no cloud AI, no network**:
- category spending vs the previous month, when the delta exceeds 10%:
  "Your grocery spending is 12% higher than last month."
- savings pace: "You're on track to save $1,920 this month."
- subscriptions: bills under $50 on a monthly recurrence, summed:
  "Your subscriptions total $184/month."
- projection vs plan: "You're projected to finish August $620 ahead of plan."
- income: received of expected when a gap remains.
Skip any insight whose inputs are missing rather than inventing a number. Return at most six,
ordered by usefulness. Percentages guard against a zero denominator.

### `InsightsView`
Month-scoped (`MonthNavigationBar`). Swift Charts, used sparingly — two charts, not a wall:
- **Income vs Expenses** — a bar mark pair for the month, with the previous month for comparison.
- **Spending by Category** — a horizontal bar chart, descending, top six plus "Other".
Then a savings-rate row (`projection.savingsRate` as a percentage) and `SmartInsightsSection`
listing `Insight` rows with their SF Symbol.
Charts must have `.accessibilityLabel`/`.accessibilityValue` per mark and an
`.accessibilityChartDescriptor` where practical — a chart that only works visually is a bug.
Empty state when the month has no transactions.

### `SettingsView`
Grouped `Form`:
- **Profile** — name (editable), currency (picker over common ISO codes, default from locale),
  region (read-only from `Locale`).
- **Preferences** — appearance (System/Light/Dark, applied via `.preferredColorScheme`),
  Face ID toggle, haptic feedback toggle, notifications toggle (stores the preference; no
  scheduling in this task).
- **Categories** → `CategoriesSettingsView`: list income and expense categories, add, rename,
  delete with a warning when a category is in use.
- **Data** → `DataSettingsView`: export all data as JSON via `ShareLink` (`Decimal` encoded as
  string, never a float), import from a picked file with a confirmation that states how many
  records will be added, a "Load sample data" toggle bound to `appState.isSampleDataEnabled`,
  and "Erase all data" behind a typed confirmation. iCloud sync appears as a disabled row
  labelled "Coming soon" — do not implement it.
- **Security** — Face ID toggle, auto-lock interval (immediately / 1 min / 5 min / never),
  and a plain statement that data is stored only on this device.
- **About** — version, and a link to the projection method explanation.

### Face ID
`BiometricAuthenticator` wraps `LocalAuthentication`:
- `canEvaluate` reports availability and the biometry type
- `authenticate(reason:) async -> Result<Void, BiometricError>`; the reason string is
  "Unlock FlowPlan to view your finances"
- errors are mapped to a small enum — never surface a raw `NSError` to the UI
- **no custom cryptography, no secrets in `UserDefaults`.** The lock is an access gate over
  local data, and the code must say so in a comment rather than implying encryption.

`AppLockView` covers the app when `isFaceIDEnabled` is on and the app is locked: an app mark, a
factual line, and an "Unlock" button (so a failed or unavailable biometric still has a path).
`RootView` gates on it and re-locks on `scenePhase` change according to the auto-lock interval.
When Face ID is unavailable on the device, the toggle is disabled with an explanation instead of
failing at unlock time.

### Tests
- `InsightsEngineTests`: each rule fires on the data that should trigger it and stays silent when
  inputs are missing; percentage maths guards a zero denominator; message text is factual and
  contains no judgemental wording; at most six insights are returned.
- `BiometricGateTests`: the lock state machine (locked on launch when enabled, unlocked after a
  successful result, re-locked after the configured interval) using an injected fake
  authenticator — never the real `LAContext` in a test.

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` still passes, including the new insights tests
- [ ] app builds and all app tests pass, zero new warnings
- [ ] `grep -rE "import (SwiftUI|SwiftData|CoreData|UIKit)" Packages/FlowPlanDomain/Sources/` finds nothing
- [ ] Face ID is optional, off by default, and the app is fully usable with it disabled
