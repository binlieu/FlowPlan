# Codex task spec — 06 — Plan screen (income, bills, budgets, savings)

## Goal
The place where the user tells LieuFlow what they *expect*. Every edit here must move the
Projected End of Month immediately.

## Scope — touch ONLY these
- `LieuFlow/Features/Plan/PlanView.swift` (create)
- `LieuFlow/Features/Plan/IncomeSection.swift` (create)
- `LieuFlow/Features/Plan/BillsSection.swift` (create)
- `LieuFlow/Features/Plan/BudgetsSection.swift` (create)
- `LieuFlow/Features/Plan/SavingsSection.swift` (create)
- `LieuFlow/Features/Plan/EditIncomeView.swift` (create)
- `LieuFlow/Features/Plan/EditBillView.swift` (create)
- `LieuFlow/Features/Plan/EditBudgetView.swift` (create)
- `LieuFlow/Features/Plan/EditSavingsGoalView.swift` (create)
- `LieuFlow/Features/Plan/RecurrencePicker.swift` (create)
- `LieuFlow/App/RootView.swift` (edit: wire the Plan tab)
- `LieuFlowTests/PlanEditingTests.swift` (create)

Do NOT modify `Packages/LieuFlowDomain/**`, `LieuFlow/Data/**`, `AppState`, `ProjectionStore`,
anything under `Features/Home`, `Features/Projection`, `Features/Transactions`, the Xcode
project, or `docs/`.

## What to do

### `PlanView`
`MonthNavigationBar`, then four `SectionCard`s in this order — Income, Bills, Monthly Spending
Budget, Savings — each with its own totals row, matching the brief:

```
Salary            $6,500        Mortgage          $1,850      Groceries        $800
Side Income       $1,200        Electric            $145      Dining           $300
Rental Income       $800        Internet          $89.99      …
                                                              Monthly Goal   $2,000
Expected Income   $8,500        …                             Projected      $1,920
                                                              Difference        -$80
```

A compact "Projected month end: $1,420" strip pinned at the top of the screen, reading straight
from `projectionStore.projection`, so the user watches the number move as they edit. Animate it
with `.contentTransition(.numericText())`.

Each row: name, amount, and a secondary line with the recurrence ("Monthly, on the 1st") or the
budget's spent-of-limit progress. `.swipeActions` for Edit and Delete. A `+` per section adds a
new item. Every write goes through `FinanceRepository` and is followed by
`projectionStore.refresh()`.

### Editors
Each editor is a native sheet in a `Form`, with a large amount field and a Save button disabled
until valid. `EditBillView` also offers amount type (fixed / estimated / variable), category,
auto-pay and an "Active" toggle. `EditIncomeView` offers expected amount, recurrence and Active.
`EditBudgetView` offers category and monthly limit, and states plainly whether the row applies to
every month or only this one. `EditSavingsGoalView` offers name, monthly target, overall target
and an optional target date.

Deleting shows a confirmation naming the item. Deactivating (rather than deleting) is offered
first for bills and income, because history should not disappear.

### `RecurrencePicker`
One reusable control over `RecurrenceFrequency` — weekly, every two weeks, monthly, every three
months, every six months, yearly — plus the anchor date. Preview text spells out the rule in
words ("Every two weeks, from 4 Aug 2026"). This is the only place recurrence UI exists.

### Savings section specifics
Shows Monthly Goal (`savingsTarget`), Projected (`savingsCompleted + remainingSavingsGoal` — read
from the projection, do not compute), and Difference. Negative differences are shown with a
symbol and words, not colour alone.

### Tests — `PlanEditingTests.swift`
- raising a salary from 6_500 to 6_750 raises `projectedEndOfMonthBalance` by exactly 250
- raising the savings goal from 1_500 to 2_000 lowers it by exactly 500
- adding a bill lowers it by that bill's amount for the occurrences falling in the month
- deactivating a bill removes it from `remainingBills`
- adding a budget category lowers the projection by its unspent remainder only
- editing a budget that has already been overspent does not move the projection

## Done when
- [ ] build succeeds, all tests pass, zero new warnings
- [ ] every Plan edit is reflected in the Home projection with no manual refresh
- [ ] no month arithmetic anywhere in this folder — `MonthNavigationBar` and `MonthKey` own it
