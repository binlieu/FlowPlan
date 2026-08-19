# Codex task spec — 02 — SwiftData persistence, repositories, app state

## Goal
Give the app a real local-first store and a single place where the projection is recomputed,
so every screen built later just renders published state. No SwiftUI screens in this task.

## Scope — touch ONLY these (create them)
- `LieuFlow/Data/Persistence/Entities.swift`
- `LieuFlow/Data/Persistence/PersistenceController.swift`
- `LieuFlow/Data/Repositories/FinanceRepository.swift`
- `LieuFlow/Data/Seed/SampleData.swift`
- `LieuFlow/App/AppState.swift`
- `LieuFlow/App/ProjectionStore.swift`
- `LieuFlow/Shared/Formatting/MoneyFormatter.swift`
- `LieuFlow/Shared/Extensions/Decimal+LieuFlow.swift`
- `LieuFlowTests/RepositoryTests.swift`
- `LieuFlowTests/ProjectionStoreTests.swift`
- `LieuFlowTests/SeedDataTests.swift`

You MAY replace `LieuFlow/App/LieuFlowApp.swift` and `LieuFlow/App/RootView.swift`
(they are two-line placeholders) to install the `ModelContainer` and the environment objects.
`RootView` should stay a placeholder view — a `TabView` with five empty `Text` tabs is enough;
the real screens land in a later task.

Do NOT modify `Packages/LieuFlowDomain/**`, `LieuFlow.xcodeproj`, or anything in `docs/`.
Do NOT add dependencies. Do NOT build any feature screens.

## Context — the domain module is already implemented
`import LieuFlowDomain` gives you `MonthKey`, `RecurrenceRule`, `RecurrenceFrequency`,
`TransactionType`, `BillAmountType`, `PlannedIncome`, `PlannedBill`, `BudgetAllocation`,
`SavingsPlan`, `TransactionSnapshot`, `ProjectionInput`, `ProjectionConfiguration`,
`MonthlyProjection`, `WhatIfScenario`, `MonthlyProjectionEngine`.
**Read the actual sources in `Packages/LieuFlowDomain/Sources/LieuFlowDomain/` first and match
the real initialisers.** Do not guess signatures, and do not change that package.

## What to do

### 1. `Entities.swift` — SwiftData `@Model` classes
One class per concept. Money is `Decimal`. Enums are stored as their `String` raw value with a
computed non-optional accessor that falls back to a sane default, so a bad value can never crash.

- `TransactionEntity` — `id: UUID`, `date: Date`, `amount: Decimal` (positive magnitude),
  `typeRaw: String`, `category: String`, `detail: String`, `note: String`, `account: String`,
  `settlesBillID: UUID?`, `settlesIncomeID: UUID?`, `createdAt: Date`, `updatedAt: Date`.
  `#Unique<TransactionEntity>([\.id])`.
- `IncomeSourceEntity` — `id`, `name`, `expectedAmount: Decimal`, `frequencyRaw: String`,
  `anchorDate: Date`, `endDate: Date?`, `isActive: Bool`.
- `RecurringBillEntity` — `id`, `name`, `amount: Decimal`, `amountTypeRaw: String`,
  `category: String`, `frequencyRaw: String`, `anchorDate: Date`, `endDate: Date?`,
  `isAutoPay: Bool`, `isActive: Bool`.
- `BudgetEntity` — `id`, `category: String`, `monthlyLimit: Decimal`,
  `scopeYear: Int?`, `scopeMonth: Int?`. A row with nil scope is the **default** budget that
  applies to every month; a row with a scope is a **per-month override**.
- `SavingsGoalEntity` — `id`, `name`, `targetAmount: Decimal`, `monthlyTarget: Decimal`,
  `currentAmount: Decimal`, `targetDate: Date?`, `isActive: Bool`.
- `MonthSettingsEntity` — `id`, `year: Int`, `month: Int`, `startingBalance: Decimal`.
  One row per month; the starting available cash for that month.

Each entity gets a `toDomain(...)` mapping into the matching domain value type. Entities never
leave the Data layer — repositories return domain values only.

### 2. `PersistenceController.swift`
- `static let shared` with an on-disk `ModelContainer` over the full schema.
- `static func inMemory() throws -> ModelContainer` for tests and previews
  (`ModelConfiguration(isStoredInMemoryOnly: true)`).
- Container creation must not `fatalError` silently — on failure, fall back to in-memory and
  log a single non-financial message via `os.Logger`.
- **Never log amounts, merchant names, or any financial value.** Logging is limited to counts
  and control-flow messages.

### 3. `FinanceRepository.swift`
`@MainActor final class FinanceRepository` holding a `ModelContext`.

Reads:
- `func projectionInput(for month: MonthKey, referenceDate: Date, configuration: ProjectionConfiguration) -> ProjectionInput`
  — fetches everything for the month and assembles the engine input.
- `func transactions(in month: MonthKey) -> [TransactionSnapshot]` (sorted newest first)
- `func incomeSources() -> [PlannedIncome]`, `func bills() -> [PlannedBill]`,
  `func savingsPlans() -> [SavingsPlan]`
- `func budgets(for month: MonthKey) -> [BudgetAllocation]` — **resolution rule:** if any rows
  carry that exact `scopeYear`/`scopeMonth`, return those; otherwise return the nil-scope
  defaults. Never mix the two sets.
- `func startingBalance(for month: MonthKey) -> Decimal` — the row's value, else `.zero`.

Writes (all `throws`, all call `context.save()`, all set `updatedAt`):
- add / update / delete for transactions, income sources, bills, budgets, savings goals
- `func setStartingBalance(_:for:)` — upsert on the month row
- `func markBillPaid(billID: UUID, occurrence: Date, amount: Decimal, on date: Date) throws`
  — creates an `.expense` transaction with `settlesBillID` set. **This is the only supported way
  to settle a bill**; it is what keeps the projection from double counting.
- `func markIncomeReceived(incomeID: UUID, amount: Decimal, on date: Date) throws` — same shape
  with `settlesIncomeID`.

Fetch by month must use a `#Predicate` on a date range built from `MonthKey.startDate` /
`endDate`, not by loading every transaction and filtering in memory.

### 4. `AppState.swift`
`@Observable @MainActor final class AppState`:
- `var selectedMonth: MonthKey` (defaults to the month of `Date()` — the app layer may read the
  clock; the engine may not)
- `func goToPreviousMonth()`, `func goToNextMonth()`, `func goToCurrentMonth()`
- `var canGoForward: Bool` — allow at most 12 months past the current month
- preferences via `@AppStorage`-backed properties: `userName` (default "Alex"),
  `currencyCode` (default `Locale.current.currency?.identifier ?? "USD"`),
  `isFaceIDEnabled`, `isHapticsEnabled`, `appearancePreference` (system/light/dark),
  `isSampleDataEnabled`. Preferences only — **no financial values in UserDefaults.**

### 5. `ProjectionStore.swift`
`@Observable @MainActor final class ProjectionStore` — the single recomputation point.
- holds `private(set) var projection: MonthlyProjection`
- `init(repository:appState:engine: MonthlyProjectionEngine = .init())`
- `func refresh()` — rebuild `ProjectionInput` from the repository for `appState.selectedMonth`
  with `referenceDate: Date()` and call the engine **once**
- `func simulate(_ scenario: WhatIfScenario) -> WhatIfResult` — delegates to the engine; must not
  mutate stored state and must not persist anything
- Every repository write path in the app calls `refresh()` afterwards. Views must never call the
  engine themselves.

### 6. `SampleData.swift`
`enum SampleData` with `static func seed(into context: ModelContext, calendar: Calendar) throws`
and `static func isSeeded(_ context: ModelContext) -> Bool`.

Seeds **August 2026** exactly as the brief specifies:
- income: Salary 6_500, Side Income 1_200, Rental Income 800 (monthly)
- bills: Mortgage 1_850, Electric 145, Internet 89.99, Phone 120, Insurance 165, Netflix 22.99
- budgets: Groceries 800, Dining 300, Gas 250, Shopping 300, Entertainment 150, Miscellaneous 250
- a savings goal with `monthlyTarget` 2_000
- a starting balance for Aug 2026 of 2_400
- a handful of realistic transactions inside August 2026 totalling roughly:
  Groceries 720, Dining 260, Gas 190, Shopping 490, Entertainment 140, Other 210,
  plus one salary deposit linked with `settlesIncomeID`, plus the mortgage paid via
  `settlesBillID` — so the seed exercises reconciliation rather than only the happy path.

Seeding is **opt-in and idempotent**: it runs only when `AppState.isSampleDataEnabled` is true
and `isSeeded` is false, and it must be trivially disabled. It must never run in a test unless
the test asks for it.

### 7. `MoneyFormatter.swift` and `Decimal+LieuFlow.swift`
- `MoneyFormatter.string(_ amount: Decimal, currencyCode: String, signed: Bool = false) -> String`
  built on `amount.formatted(.currency(code:))`. Never concatenate `"$"`. Do not assume 2 dp.
- `func accessibleString(_ amount: Decimal, currencyCode: String) -> String` — a spoken form for
  VoiceOver, e.g. "1,420 dollars remaining" style, no bare glyphs.
- `Decimal` helpers only if genuinely needed (`rounded(_:scale:)`). No `Double` bridging.

## Tests
Swift Testing. Use `PersistenceController.inMemory()` — never the on-disk store.
- round-trip each entity through `toDomain` and back
- `budgets(for:)` returns the override set when one exists and the defaults otherwise, never mixed
- `transactions(in:)` returns only the requested month, including the first and last day
- `markBillPaid` creates exactly one linked transaction, and the projection's
  `projectedEndOfMonthBalance` is **unchanged** by it while `remainingBills` drops — the
  double-counting regression test at the app layer
- `ProjectionStore.refresh()` after adding a 600 expense moves the projection by exactly −600
- `simulate` does not persist anything and leaves `projection` untouched
- seeding is idempotent (running twice yields one set of rows) and produces the brief's numbers

## Done when
- [ ] `xcodebuild -scheme LieuFlow -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds
- [ ] `xcodebuild -scheme LieuFlow -destination 'platform=iOS Simulator,name=iPhone 17' test` passes
- [ ] zero new warnings
- [ ] `grep -rn "import SwiftUI" LieuFlow/Data/` finds nothing
- [ ] no financial value is written to `UserDefaults` or to any log
