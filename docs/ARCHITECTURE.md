# LieuFlow — Architecture

> Every layer below exists to answer one question:
> **"What will my financial situation look like at the end of this month?"**

## 1. Module map

```
LieuFlow/                          repo root
├── Packages/LieuFlowDomain/       ← PURE SWIFT. Foundation only. No UI, no storage.
│   └── Sources/LieuFlowDomain/
│       ├── Models/                value types: PlannedIncome, PlannedBill, BudgetAllocation,
│       │                          SavingsPlan, TransactionSnapshot, MonthlyProjection…
│       ├── Calculations/          MonthlyProjectionEngine, InsightsEngine
│       └── Support/               MonthKey, RecurrenceRule, Money formatting helpers
│
├── LieuFlow/                      app target (iOS 18+)
│   ├── App/                       LieuFlowApp, RootView, AppState, MonthSelection
│   ├── Data/
│   │   ├── Persistence/           SwiftData @Model entities + ModelContainer setup
│   │   ├── Repositories/          entity ⇄ domain-value mapping, CRUD
│   │   └── Seed/                  sample data, isolated behind a flag
│   ├── Features/                  Home, Projection, Transactions, Plan, Insights, Settings
│   ├── Shared/                    Components, Extensions, Formatting
│   └── Resources/                 Assets.xcassets
│
└── LieuFlowTests/                 app-level tests (repositories, mapping, view models)
```

Dependency direction is one-way and enforced by module boundaries:

```
Features ──▶ Repositories ──▶ SwiftData entities
    │              │
    └──────────────┴──▶ LieuFlowDomain   (nothing in the domain depends on anything above it)
```

## 2. The purity rule (non-negotiable)

`LieuFlowDomain` imports **`Foundation` and nothing else**. No SwiftUI, SwiftData, CoreData,
UIKit, Combine or Observation. No `Date()` inside the engine — the caller injects
`referenceDate`, which is what makes month-boundary behaviour testable.

Why it is a separate SPM package rather than a folder:

- A violation becomes a **compile error**, not a review comment.
- The engine is testable with `swift test` in seconds — no simulator, no store, no app host.
- The same engine can later power a WidgetKit extension, Apple Watch, Shortcuts/App Intents
  and the What-If simulator **without the financial logic being rewritten or forked**.

There is exactly one implementation of the projection maths in the product. Views never do
arithmetic; they render `MonthlyProjection` fields and its `breakdown` rows.

## 3. Money

- `Decimal` everywhere. Never `Double`/`Float` in a money path.
- Amounts are stored as **positive magnitudes**; `TransactionType` carries the direction.
- Formatting goes through a single `MoneyFormatter` using `Decimal.formatted(.currency(code:))`,
  driven by the user's selected currency code — never a hard-coded `"$"`.
- Safe-to-spend rounds **down** to 2 dp (`NSDecimalRound(.down)`) so the app never over-promises.

## 4. The projection model

Three states a financial event can be in:

| State | Meaning | Where it is counted |
|---|---|---|
| **Actual** | already happened (a `TransactionSnapshot`) | `currentAvailableBalance` |
| **Expected** | income or a bill occurrence still due this month | `remainingExpectedIncome`, `remainingBills` |
| **Planned** | budget allowance or savings target not yet spent/saved | `remainingVariableSpending`, `remainingSavingsGoal` |

```
currentAvailableBalance = startingBalance + incomeReceived − expensesPaid − savingsCompleted

projectedEndOfMonthBalance = currentAvailableBalance
                           + remainingExpectedIncome
                           − remainingBills
                           − remainingVariableSpending
                           − remainingSavingsGoal
```

**The double-counting guarantee.** Actual events appear only in line 1. Outstanding
obligations appear only in line 2. Nothing appears in both. Marking a bill paid moves it
across the boundary — it leaves `remainingBills` and enters `expensesPaid` — so the projected
balance is *unchanged*, which is exactly the behaviour a user expects and is covered by a
dedicated regression test.

Reconciliation is driven by **explicit links**: a transaction may carry `settlesBillID` or
`settlesIncomeID`. Occurrences are settled in date order, so two paychecks settle two of three
expected occurrences and the third stays outstanding. Unlinked income is *extra* income: it
raises the total without reducing what is still expected.

Budgets behave as allowances, not forecasts: a category contributes `max(0, limit − spent)` to
the remaining projection, so spending inside budget does not move the projection, and
overspending moves it by the overspend only. Discretionary spending in an unbudgeted category
moves the projection by its full amount.

## 5. Safe to Spend

```
spendableRemaining = currentAvailableBalance + remainingExpectedIncome
                   − remainingBills − remainingSavingsGoal

dailySafeToSpend   = daysRemaining > 0 ? max(0, spendableRemaining) / daysRemaining : 0
```

This deliberately ignores the *planned* variable budget: safe-to-spend is derived from money
that actually exists and is not committed, not from the plan. `daysRemaining == 0` returns 0
and never divides by zero.

## 6. Recurrence

`RecurrenceRule` is a rule, not a table. Occurrences for a month are computed on demand by
`occurrences(in:calendar:)`. **No future rows are ever written to the store.** Monthly-family
frequencies clamp to the last day of short months (anchor Jan 31 → Feb 28/29 → Mar 31).

## 7. Persistence

SwiftData, chosen because the toolchain floor (iOS 18) supports it comfortably and it removes
a large amount of Core Data boilerplate. `@Model` entities live **only** in
`LieuFlow/Data/Persistence` and are never handed to a view or to the engine. Repositories map
entities to domain value types on the way out and apply edits on the way in. Swapping SwiftData
for another store therefore touches one folder.

## 8. State and recomputation

- `AppState` (`@Observable`) owns the selected `MonthKey` and user preferences.
- A single `ProjectionStore` observes the model context and the selected month, rebuilds
  `ProjectionInput` from the repositories, and calls the engine **once** per change,
  publishing the resulting `MonthlyProjection`.
- Views read the published projection. They never call the engine in a `body` property and
  never recompute totals, so adding a transaction updates the dashboard immediately with one
  engine call rather than one per view.

## 9. Navigation

Native `TabView`: Home · Transactions · Plan · Insights · Settings, each with a
`NavigationStack`. Month selection is a single reusable component bound to `AppState`, so
changing the month updates every screen at once instead of each screen owning month logic.

## 10. Testing strategy

| Layer | Tool | Runs with |
|---|---|---|
| Domain / engine | Swift Testing | `swift test` (seconds, no simulator) |
| Repositories & mapping | Swift Testing | `xcodebuild test` against an in-memory `ModelContainer` |
| UI flows | XCUITest (where practical) | `xcodebuild test` |

The engine suite is the product's safety net and is expected to stay the largest.
