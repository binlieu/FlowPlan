# Codex task spec — 06 — Plan screen (income, bills, budgets, savings, monthly projection)

## Goal
Build the Plan tab to match the design handoff. This is where the user states what they *expect*,
and it is also where the full monthly projection now lives.

## Scope — touch ONLY these (create unless noted)
- `FlowPlan/Features/Plan/PlanView.swift`
- `FlowPlan/Features/Plan/ExpectedIncomeSection.swift`
- `FlowPlan/Features/Plan/MonthlyBillsSection.swift`
- `FlowPlan/Features/Plan/SpendingBudgetSection.swift`
- `FlowPlan/Features/Plan/SavingsGoalSection.swift`
- `FlowPlan/Features/Plan/MonthlyProjectionCard.swift`
- `FlowPlan/Features/Plan/EditIncomeView.swift`
- `FlowPlan/Features/Plan/EditBillView.swift`
- `FlowPlan/Features/Plan/EditBudgetView.swift`
- `FlowPlan/Features/Plan/EditSavingsGoalView.swift`
- `FlowPlan/Features/Plan/RecurrencePicker.swift`
- `FlowPlan/Shared/DesignSystem/Chip.swift`
- `FlowPlan/Shared/DesignSystem/BudgetProgressBar.swift`
- `FlowPlan/App/RootView.swift` (edit: wire the Plan tab)
- `FlowPlanTests/PlanEditingTests.swift`

Do NOT modify `Packages/FlowPlanDomain/**`, `FlowPlan/Data/**`, `AppState`, `ProjectionStore`,
`Features/Home/**`, `Features/Projection/**`, `Features/Transactions/**`, or the Xcode project.

## Design system — already exists, reuse it
`Palette`, `Typography`, `TickCard` and `MoneyFormatter.compact` are in
`FlowPlan/Shared/DesignSystem/` and `Shared/Formatting/`. Read them and use them. Do not
introduce new colours, and do not hard-code hex.

## Layout — top to bottom, matching the handoff

Header: `Plan` as a large bold title with the month in small caps beneath (`AUGUST 2026`).
Plan uses a **title + subtitle**, not Home's bracketed chevron bar — but the month still comes
from `appState.selectedMonth`, and changing month elsewhere must update this screen.

### 1. Expected Income — heading with a trailing `Add` link
Rows in a bordered group: name, a secondary subtitle describing the recurrence in words
("Monthly · 15th & last day"), amount trailing in compact style. Final row is a **tinted total
row**: `TOTAL EXPECTED INCOME` … `+$8,500`.

### 2. Monthly Bills — heading with `Add`
Each row: name; beneath it two `Chip`s — an **outlined accent chip** for the amount type
(`FIXED` / `ESTIMATED` / `VARIABLE`) and a **filled neutral chip** for payment
(`AUTO PAY` / `MANUAL`); amount trailing, with `Due 21st` in secondary text beneath it.

### 3. Spending Budget — heading with `Add`
One row per budgeted category: name, `{spent} of {limit}` trailing, a progress bar, and a footer
line. Within budget → solid accent bar and `${remaining} remaining`. **Over budget → a
diagonally hatched bar** (same treatment as the Home cash-flow remainder) and
`${overspend} over budget`. Never draw a bar past 100% — clamp the fill and switch to the hatch.

### 4. Savings Goal
Current monthly target, progress toward it, and a **"Drag to re-plan the month" slider** with the
range labelled at both ends. Dragging changes the savings target live and the projection card
below updates as it moves. Commit the change to the repository on drag end, not on every frame,
then call `projectionStore.refresh()`.

### 5. `MonthlyProjectionCard` (TickCard) — the projection's new home
Label `MONTHLY PROJECTION`, then rows, then an emphasised total:

```
Expected income        +$8,500
Recurring bills        -$2,393
Planned spending       -$3,500
Savings goal           -$2,000
─────────────────────────────────
PROJECTED REMAINING      +$607
```

Every figure comes from `projectionStore.projection`:
`totalExpectedIncome`, the planned bills and planned budget totals, `savingsTarget`, and
`plannedEndOfMonthBalance` for the total. **Do no arithmetic in the view.** If a planned total
you need is not exposed on `MonthlyProjection`, stop and report it rather than computing it.

The handoff also shows a `Debt payments` row. **Debt is deferred (DECISIONS.md D-014) — omit that
row entirely.** Do not invent a debt model, and do not leave a zero-valued placeholder row.

Tapping the card opens the existing `ProjectionDetailView`.

## Editors
Native sheets in `Form`s, each with a large amount field and a Save button disabled until valid.
`EditBillView` covers amount type, category, due day, recurrence, auto-pay and Active.
`EditIncomeView` covers expected amount, recurrence and Active. `EditBudgetView` covers category
and monthly limit, and states plainly whether the row applies to every month or only this one.
`EditSavingsGoalView` covers name, monthly target, overall target and an optional target date.

Deleting asks for confirmation naming the item. For bills and income, offer **deactivate** before
delete, so history is not destroyed.

`RecurrencePicker` is the single reusable recurrence control — weekly, every two weeks, monthly,
every three months, every six months, yearly — plus the anchor date, with a plain-words preview
("Every two weeks, from 4 Aug 2026"). No other screen may implement recurrence UI.

Every write goes through `FinanceRepository` and is followed by `projectionStore.refresh()`.

## Tests — `PlanEditingTests.swift`
- raising a salary from 6,500 to 6,750 raises `plannedEndOfMonthBalance` by exactly 250
- raising the savings goal by 500 lowers `projectedEndOfMonthBalance` by exactly 500
- adding a bill lowers the projection by that bill's amount for occurrences in the month
- deactivating a bill removes it from `remainingBills`
- adding a budget category lowers the projection by its unspent remainder only
- editing a budget that is already overspent does not move the projection
- the projection card's rows and total match `MonthlyProjection` exactly

## Done when
- [ ] builds for the iPhone 17 simulator, no new warnings
- [ ] all 86 existing tests plus the new ones pass
- [ ] `grep -rnE "Color\(red:|#colorLiteral|Color\(hex" FlowPlan/` finds nothing
- [ ] no month arithmetic in this folder — `MonthKey` and `AppState` own it
- [ ] every Plan edit moves the Home figures with no manual refresh
