# Codex task spec — 06c — The Plan projection card must reconcile

## Goal
Fix a trust defect: the `MONTHLY PROJECTION` card shows rows that do not add up to its own total.

## Scope — touch ONLY these
- `FlowPlan/Features/Plan/MonthlyProjectionCard.swift`
- `FlowPlanTests/PlanEditingTests.swift`
- `FlowPlan/Features/Plan/SavingsGoalSection.swift` (slider range only)

Do NOT modify the domain package, `Data/`, `AppState`, `ProjectionStore`, or any other feature.

## Defect — confirmed on device with seeded August 2026

The card renders:

```
Expected income        +$8,500.00
Recurring bills        -$2,392.98
Planned spending       -$2,050.00
Savings goal           -$2,000.00
PROJECTED REMAINING    +$4,457.02
```

The four rows sum to **$2,057.02**, not the $4,457.02 shown. The missing $2,400 is
`projection.startingBalance`, which `plannedEndOfMonthBalance` includes but the card omits.

The total is right; the breakdown is incomplete. A user who checks the arithmetic — exactly the
user this card exists to serve — finds it does not work.

## Fix
Add a leading row for the starting balance, so the card reconciles:

```
Starting balance       +$2,400.00     ← projection.startingBalance
Expected income        +$8,500.00     ← plannedIncomeTotal
Recurring bills        -$2,392.98     ← plannedBillsTotal
Planned spending       -$2,050.00     ← plannedSpendingTotal
Savings goal           -$2,000.00     ← savingsTarget
──────────────────────────────────
PROJECTED REMAINING    +$4,457.02     ← plannedEndOfMonthBalance
```

Style the starting-balance row like the other rows, not like the total. When
`startingBalance == .zero`, still show the row — a zero opening balance is information, and
hiding it makes the card reconcile only sometimes, which is worse than always showing it.

Give the card an `.accessibilityElement(children: .contain)` so the rows are read in order and
the total is reachable.

## Also fix
The savings slider range is `$0 … $10,000`, which makes the handle sit near the far left and
gives almost no useful precision around a realistic target. Bound it to
`0 … max(4_000, savingsTarget * 2)` rounded up to a sensible step, with a step of 50. Label both
ends as it does now.

## Tests
Add to `PlanEditingTests.swift`:
- **the reconciliation invariant**: the card's displayed row values sum exactly to its displayed
  total, asserted across at least three scenarios — a zero starting balance, a non-zero starting
  balance, and a month with no plan at all. Assert on the same values the view renders, not on a
  re-derivation, so the test fails if a row is ever dropped again.
- changing the savings target via the slider commit path moves `plannedEndOfMonthBalance` by the
  same amount and the card's total follows.

## Done when
- [ ] builds for the iPhone 17 simulator, no new warnings
- [ ] all 97 existing tests pass, plus the new ones
- [ ] the rows visibly sum to the total with seeded data
