# Codex task spec — 27 — Totals for Spending Budget and Savings

## Goal
Spending Budget and Savings are the only Plan sections without a total row. Add them, completing
the set.

## The principle to lock in
After this change, **every Plan section total is exactly one row of the Monthly Projection card**:

| Plan section total | Projection card row | Source |
|---|---|---|
| `TOTAL EXPECTED INCOME` | Expected income | `plannedIncomeTotal` |
| `TOTAL MONTHLY BILLS` | Recurring bills | `plannedBillsTotal` |
| `OUTSIDE MONTHLY BILLS` | Debt payments | debt total outside bills |
| `TOTAL SPENDING BUDGET` | Planned spending | `plannedSpendingTotal` |
| `TOTAL SAVINGS GOAL` | Savings goal | `savingsTarget` |

Read each figure from `projectionStore.projection`. **Do not sum the rows in the view.** The
projection card and the section totals must be incapable of disagreeing — two different numbers
for the same thing on one screen is the trust failure this app exists to avoid.

## Scope
- `FlowPlan/Features/Plan/SpendingBudgetSection.swift`
- `FlowPlan/Features/Plan/SavingsGoalSection.swift`
- `FlowPlan/Features/Plan/PlanView.swift` (pass the values through)
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**` — every value already exists. All 106 domain tests must
pass unchanged. Use the existing `PlanTotalRow`; do not restyle or fork it.

## What to add
- **Spending Budget:** `TOTAL SPENDING BUDGET` … `-$2,050`, from `plannedSpendingTotal`. This is
  the budgeted total for the month, not what has been spent — the per-row "spent of limit" detail
  already covers actuals.
- **Savings:** `TOTAL SAVINGS GOAL` … `-$2,000`, from `savingsTarget`. Negative, because it is
  money set aside and leaves the projection the same way bills do — consistent with how the
  projection card presents it.

Both render zero rather than disappearing when empty, as bills already does.

The savings section already shows Monthly Goal / Projected / Difference for a single goal. Keep
that detail; the total is the sum across all savings plans and is what matters when there is more
than one.

## Tests
- each total equals its corresponding `MonthlyProjection` field
- each Plan section total equals the matching Monthly Projection card row — assert them against
  each other, so the two can never drift
- adding or removing a budget category moves the spending total
- a second savings goal is included in the savings total
- empty sections render a zero total rather than omitting the row

## Done when
- [ ] all five Plan totals use `PlanTotalRow` and read from the projection
- [ ] `grep -rn "reduce(\|\.sum" FlowPlan/Features/Plan/SpendingBudgetSection.swift FlowPlan/Features/Plan/SavingsGoalSection.swift` shows no total being summed in the view
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
