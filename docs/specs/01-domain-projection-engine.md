# Codex task spec — 01 — FlowPlanDomain: models + MonthlyProjectionEngine

## Goal
Implement the pure-Swift financial core of FlowPlan: value-type domain models, a recurrence
rule, and `MonthlyProjectionEngine`, plus a thorough test suite. `swift test` must pass.

## Scope — touch ONLY these
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/**`
- `Packages/FlowPlanDomain/Tests/FlowPlanDomainTests/**`

Delete `Sources/FlowPlanDomain/Support/Placeholder.swift` and
`Tests/FlowPlanDomainTests/PlaceholderTests.swift` — they are scaffolding anchors.

Do NOT modify `Package.swift`, the Xcode project, the `FlowPlan/` app target, or any doc.
Do NOT add dependencies.

## HARD CONSTRAINT — purity
This target imports **`Foundation` only**. Never import SwiftUI, SwiftData, CoreData,
UIKit, Combine or Observation. No `@Model`, `@Observable`, `@Published`, no classes with
reference semantics for domain data, no I/O, no singletons, no `Date()` inside the engine
(the caller passes `referenceDate`). Everything `public`, `Sendable`, and value-typed.
All money is `Decimal`. Never `Double`/`Float` for money.

## Architecture the engine must implement

### Support types
```swift
public struct MonthKey: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int            // 1...12
    public init(year: Int, month: Int)          // normalises out-of-range month
    public init(date: Date, calendar: Calendar)
    public var next: MonthKey { get }
    public var previous: MonthKey { get }
    public func startDate(calendar: Calendar) -> Date
    public func endDate(calendar: Calendar) -> Date      // last instant of the month
    public func dayCount(calendar: Calendar) -> Int
    public func contains(_ date: Date, calendar: Calendar) -> Bool
    public func adding(months: Int) -> MonthKey
}

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case income, expense, transfer, savings
}

public enum BillAmountType: String, Codable, CaseIterable, Sendable {
    case fixed, estimated, variable
}

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case weekly, biweekly, monthly, quarterly, semiannually, annually
}

/// Rule-based recurrence. NEVER materialise future rows — compute occurrences on demand.
public struct RecurrenceRule: Hashable, Codable, Sendable {
    public let frequency: RecurrenceFrequency
    public let anchorDate: Date       // first occurrence
    public let endDate: Date?         // nil == open ended
    public init(frequency: RecurrenceFrequency, anchorDate: Date, endDate: Date? = nil)
    /// All occurrence dates that fall inside `month`. Empty if the rule has ended.
    public func occurrences(in month: MonthKey, calendar: Calendar) -> [Date]
}
```
Monthly-family recurrences must clamp to the last day of short months (anchor Jan 31 →
Feb 28/29 → Mar 31). `biweekly` = every 14 days from the anchor. `weekly` = every 7 days.

### Plan inputs (what the user intends)
```swift
public struct PlannedIncome: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let expectedAmount: Decimal        // positive
    public let recurrence: RecurrenceRule
    public let isActive: Bool
}

public struct PlannedBill: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let amount: Decimal                // positive
    public let amountType: BillAmountType
    public let category: String
    public let recurrence: RecurrenceRule
    public let isAutoPay: Bool
    public let isActive: Bool
}

public struct BudgetAllocation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let category: String
    public let monthlyLimit: Decimal          // positive
}

public struct SavingsPlan: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let monthlyTarget: Decimal         // positive, may be .zero
}
```

### Actuals
```swift
public struct TransactionSnapshot: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let amount: Decimal                // ALWAYS a positive magnitude; `type` carries direction
    public let type: TransactionType
    public let category: String
    public let detail: String                 // merchant / description
    /// Reconciliation links — the ONLY mechanism that retires an expectation.
    public let settlesBillID: UUID?
    public let settlesIncomeID: UUID?
}
```

### Engine input
```swift
public struct ProjectionConfiguration: Hashable, Codable, Sendable {
    public var tightThreshold: Decimal        // default 200
    public var aheadOfPlanThreshold: Decimal  // default 100
    public static let `default`: ProjectionConfiguration
}

public struct ProjectionInput: Sendable {
    public let month: MonthKey
    public let referenceDate: Date            // "now" — injected, never Date() internally
    public let startingBalance: Decimal       // available cash at the first instant of the month
    public let incomeSources: [PlannedIncome]
    public let bills: [PlannedBill]
    public let budgets: [BudgetAllocation]
    public let savingsPlans: [SavingsPlan]
    public let transactions: [TransactionSnapshot]   // caller passes the whole month; engine filters
    public let calendar: Calendar
    public let configuration: ProjectionConfiguration
    // memberwise public init with sensible defaults for calendar/configuration
}
```

### Output
```swift
public enum ProjectionStatus: String, Codable, Sendable {
    case aheadOfPlan, healthy, tight, negative
}

public struct ProjectionCompleteness: Hashable, Codable, Sendable {
    public let hasStartingBalance: Bool
    public let hasPlannedIncome: Bool
    public let hasBills: Bool
    public let hasSpendingBudget: Bool
    public let hasSavingsGoal: Bool
    public var isComplete: Bool { get }
    public var missing: [String] { get }       // human-readable, stable order
}

/// One row of the tap-through breakdown. The UI renders these in order; it must never
/// recompute arithmetic of its own.
public struct ProjectionLineItem: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case opening, addition, deduction, total }
    public let id: String                      // stable key, e.g. "remainingBills"
    public let label: String
    public let amount: Decimal                 // signed as displayed
    public let kind: Kind
}

public struct MonthlyProjection: Hashable, Sendable {
    public let month: MonthKey

    public let totalExpectedIncome: Decimal
    public let incomeReceived: Decimal
    public let remainingExpectedIncome: Decimal

    public let expensesPaid: Decimal
    public let remainingBills: Decimal
    public let billsPaid: Decimal
    public let projectedVariableSpending: Decimal
    public let actualVariableSpending: Decimal
    public let remainingVariableSpending: Decimal

    public let savingsCompleted: Decimal
    public let remainingSavingsGoal: Decimal
    public let savingsTarget: Decimal

    public let startingBalance: Decimal
    public let currentAvailableBalance: Decimal
    public let projectedEndOfMonthBalance: Decimal
    public let plannedEndOfMonthBalance: Decimal
    public let varianceVsPlan: Decimal

    public let spendableRemaining: Decimal
    public let dailySafeToSpend: Decimal

    public let daysRemaining: Int
    public let daysInMonth: Int
    public let savingsRate: Decimal            // 0...1

    public let status: ProjectionStatus
    public let completeness: ProjectionCompleteness
    public let breakdown: [ProjectionLineItem]
}
```

### The rules — implement EXACTLY. Comment each one in code.
Only transactions whose `date` falls inside `month` are considered. `.transfer` is ignored
entirely (money moving between the user's own accounts is projection-neutral).

1. `incomeReceived` = Σ amount of `.income` transactions in the month.
2. An income occurrence is **settled** if any `.income` transaction in the month has
   `settlesIncomeID == source.id`. `remainingExpectedIncome` = Σ `expectedAmount` over every
   occurrence (from `recurrence.occurrences(in:)`, active sources only) that is *not* settled.
   One transaction settles at most one occurrence — settle occurrences in date order, so two
   paychecks settle two occurrences and a third occurrence stays outstanding.
3. `totalExpectedIncome` = `incomeReceived + remainingExpectedIncome`. Unlinked income is
   therefore extra income; it raises the total and never reduces what is still expected.
4. `billsPaid` = Σ amount of `.expense` transactions with a non-nil `settlesBillID`.
   A bill occurrence is settled by matching `settlesBillID`, occurrences settled in date order.
   `remainingBills` = Σ `amount` over unsettled occurrences of active bills — including
   occurrences whose due date has already passed (overdue is still owed).
5. `actualVariableSpending` = Σ amount of `.expense` transactions with `settlesBillID == nil`
   (discretionary spending).
6. Per budgeted category: `spent` = Σ discretionary expense in that category;
   `remaining` = max(0, limit − spent). `remainingVariableSpending` = Σ of those remainders.
   `projectedVariableSpending` = `actualVariableSpending + remainingVariableSpending`.
   Overspending a category contributes 0 remaining — never a negative.
   Discretionary spending in an unbudgeted category still counts in `actualVariableSpending`.
7. `expensesPaid` = `billsPaid + actualVariableSpending`.
8. `savingsCompleted` = Σ amount of `.savings` transactions. `savingsTarget` = Σ
   `monthlyTarget` of all plans. `remainingSavingsGoal` = max(0, savingsTarget − savingsCompleted).
9. `currentAvailableBalance` = `startingBalance + incomeReceived − expensesPaid − savingsCompleted`.
   (Every actual event is counted here exactly once.)
10. `projectedEndOfMonthBalance` = `currentAvailableBalance + remainingExpectedIncome
    − remainingBills − remainingVariableSpending − remainingSavingsGoal`.
    (Every outstanding obligation is counted here exactly once. Nothing is counted in both 9 and 10 —
    this is the double-counting guarantee.)
11. `plannedEndOfMonthBalance` = plan only, ignoring actuals: `startingBalance` + Σ all income
    occurrences × expectedAmount − Σ all bill occurrences × amount − Σ budget limits − savingsTarget.
    `varianceVsPlan` = `projectedEndOfMonthBalance − plannedEndOfMonthBalance`.
12. `spendableRemaining` = `currentAvailableBalance + remainingExpectedIncome − remainingBills
    − remainingSavingsGoal`. This deliberately ignores the *planned* variable budget: safe-to-spend
    is derived from real available money, not from the plan.
13. `daysRemaining`: if `referenceDate` is before the month → `daysInMonth`; after the month → 0;
    inside the month → days from the start of `referenceDate`'s day through the last day, inclusive
    (so on the last day of the month it is 1).
14. `dailySafeToSpend` = `daysRemaining > 0 ? max(0, spendableRemaining) / daysRemaining : 0`.
    NEVER divide by zero. Round to 2 dp using `NSDecimalRound` with `.down` (never over-promise).
15. `savingsRate` = `totalExpectedIncome > 0 ? (savingsCompleted + remainingSavingsGoal) /
    totalExpectedIncome : 0`.
16. `status`: `negative` if projected < 0; else `tight` if projected < `tightThreshold`; else
    `aheadOfPlan` if `varianceVsPlan > aheadOfPlanThreshold`; else `healthy`.
17. Never clamp `projectedEndOfMonthBalance` — negative results are legitimate and must survive.
18. `breakdown` rows, in this exact order and with these ids:
    `currentAvailable` (opening), `remainingIncome` (addition, +),
    `remainingBills` (deduction, −), `remainingSpending` (deduction, −),
    `remainingSavings` (deduction, −), `projectedBalance` (total).
    Deduction amounts are stored negative. The rows must sum to `projectedEndOfMonthBalance`.

### What-If — same engine, no duplicated maths
```swift
public struct WhatIfScenario: Hashable, Sendable {
    public let additionalTransactions: [TransactionSnapshot]
    public let savingsTargetOverride: Decimal?
    public init(additionalTransactions: [TransactionSnapshot] = [], savingsTargetOverride: Decimal? = nil)
}

public struct WhatIfResult: Hashable, Sendable {
    public let base: MonthlyProjection
    public let simulated: MonthlyProjection
    public var impact: Decimal { get }   // simulated − base projected end-of-month
}

public struct MonthlyProjectionEngine: Sendable {
    public init()
    public func project(_ input: ProjectionInput) -> MonthlyProjection
    public func simulate(_ scenario: WhatIfScenario, on input: ProjectionInput) -> WhatIfResult
}
```
`simulate` must call `project` twice against derived inputs. Do not re-derive any arithmetic.

## Tests — `Packages/FlowPlanDomain/Tests/FlowPlanDomainTests/`
Use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. Split into files:
`MonthKeyTests.swift`, `RecurrenceRuleTests.swift`, `MonthlyProjectionEngineTests.swift`,
`ReconciliationTests.swift`, `SafeToSpendTests.swift`, `WhatIfTests.swift`, and a shared
`Fixtures.swift` builder. Always use a fixed `Calendar` (gregorian, UTC) and fixed dates.

Must cover, at minimum:
- Baseline: income 8_500, bills 2_393, budgets 2_500, savings 2_000, startingBalance 0,
  no transactions → projected == 1_607; and the 8_500 / 5_000 / 2_000 → 1_500 case from the brief.
- Bill marked paid: expected bill 1_850 → after a settling transaction, `remainingBills`
  drops by 1_850, `billsPaid` is 1_850, and `projectedEndOfMonthBalance` is UNCHANGED
  (the double-counting regression test).
- Extra unlinked income raises `totalExpectedIncome` and `projectedEndOfMonthBalance`
  without touching `remainingExpectedIncome`.
- Two paychecks settle two of three occurrences; one remains outstanding.
- New discretionary expense of 500 inside budget reduces projection by 0 (it consumes budget),
  and an expense that exceeds the category budget reduces the projection by the overspend only.
- Unbudgeted-category spending reduces the projection by its full amount.
- New expense of 600 (car repair, unbudgeted) moves projection by exactly −600 — the brief's
  headline acceptance test.
- Additional income of 700 raises projection by exactly 700.
- Savings target +500 lowers projection by exactly 500.
- Negative projection is preserved (e.g. −420), never clamped.
- Month boundaries: Jan (31), Feb non-leap (28), Feb leap 2028 (29), Apr (30);
  `daysRemaining` on the 1st, mid-month, last day (== 1), a past month (== 0), a future month (== daysInMonth).
- `dailySafeToSpend` with `daysRemaining == 0` returns 0 and does not trap.
- `dailySafeToSpend` example: spendable 1_200 over 15 days → 80.
- Monthly recurrence anchored Jan 31 lands on Feb 28 (2027) and Feb 29 (2028).
- Completeness flags: empty input reports every gap in `missing`.
- `breakdown` rows sum to `projectedEndOfMonthBalance` in several scenarios.
- What-If: a 1_200 purchase yields `impact == -1_200` and does not mutate the base projection.

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift build` succeeds with zero warnings.
- [ ] `cd Packages/FlowPlanDomain && swift test` passes, 45+ tests.
- [ ] `grep -rE "import (SwiftUI|SwiftData|CoreData|UIKit|Combine|Observation)" Sources/` finds nothing.
- [ ] `grep -rn "Date()" Sources/` finds nothing (reference date is always injected).
- [ ] No `Double` or `Float` anywhere in money paths.
