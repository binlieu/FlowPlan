# Codex task spec — 04 — Projection breakdown + What-If simulator

## Goal
Make the headline number trustworthy: a screen that shows exactly how it was calculated, and a
simulator that tests a hypothetical purchase against the **same engine**.

## Scope — touch ONLY these
- `FlowPlan/Features/Projection/ProjectionDetailView.swift` (create)
- `FlowPlan/Features/Projection/ProjectionBreakdownRow.swift` (create)
- `FlowPlan/Features/Projection/ProjectionCompletenessView.swift` (create)
- `FlowPlan/Features/Projection/WhatIfView.swift` (create)
- `FlowPlan/Features/Home/ProjectionHeroCard.swift` (edit: replace the spec-03 placeholder
  destination with the real `ProjectionDetailView`)
- `FlowPlanTests/ProjectionBreakdownTests.swift` (create)

Do NOT modify `Packages/FlowPlanDomain/**`, `FlowPlan/Data/**`, `AppState`, `ProjectionStore`,
the Xcode project, or `docs/`.

## What to do

### `ProjectionDetailView`
Navigation title "Projected End of August" (month from `projection.month`).

Top: the projected balance in hero style, with the same interpretation sentence as the card, so
the two screens never disagree.

Then the **breakdown**, rendered **entirely from `projection.breakdown`**:

```
Current Available          $4,250
Remaining Income          +$2,500
Upcoming Bills            -$1,480
Expected Spending         -$2,350
Savings Goal Remaining    -$1,500
─────────────────────────────────
Projected Balance          $1,420
```

Iterate the `[ProjectionLineItem]` array in order. Style by `kind` — `.opening` plain,
`.addition` with a leading `+`, `.deduction` with a leading `−`, `.total` emphasised above a
`Divider()`. **Do not compute, reorder, or re-sign anything**; the engine already did.
The view must remain correct if the engine adds a row.

Below each row, a short secondary explainer so the number is not just an assertion:
- Current Available — "Starting balance plus what's come in, minus what's gone out."
- Remaining Income — "Expected income you haven't received yet."
- Upcoming Bills — "Bills due this month that aren't paid yet."
- Expected Spending — "What's left of your category budgets."
- Savings Goal Remaining — "Still to set aside to hit your monthly goal."

Then a supporting section of secondary figures from the projection:
income received of total expected, bills paid of total, variable spending actual of projected,
savings completed of target, `daysRemaining` of `daysInMonth`, `savingsRate` as a percentage,
and `varianceVsPlan` against `plannedEndOfMonthBalance`.

Then `ProjectionCompletenessView` — a checklist driven by `projection.completeness`:
`checkmark.circle.fill` for present, `exclamationmark.triangle` for missing, one row per flag
(Income planned, Bills entered, Savings goal entered, Spending budget entered, Starting balance
entered). Header copy: "Projection based on:". If anything is missing, add the factual line
"Your projection may be incomplete because…" naming the gaps. Never imply more accuracy than the
inputs support.

A toolbar button "What If?" presents `WhatIfView` as a sheet.

### `WhatIfView`
A sheet, presented over the detail screen.

- A large amount field (`.keyboardType(.decimalPad)`, `Decimal` parsed via `FormatStyle`, never
  `Double`), a description field, and an income/expense picker.
- As the amount changes, call `projectionStore.simulate(WhatIfScenario(additionalTransactions: [...]))`
  and show:

```
Current Projection      $1,420
After Purchase            $220
Impact                 -$1,200
```

- The impact figure comes from `WhatIfResult.impact`. **Do not subtract anything yourself.**
- The simulation must **never** be saved. A single explicit "Add as Expense" button writes it as
  a real transaction through the repository and then calls `projectionStore.refresh()`; "Done"
  dismisses and changes nothing.
- Empty/zero amount shows the current projection with a neutral prompt, not a zero impact row.
- Accessibility: the three figures are one summary element that reads
  "Current projection $1,420. After this purchase, $220. Impact, minus $1,200."

### `ProjectionHeroCard` edit
Replace the spec-03 placeholder navigation destination with `ProjectionDetailView`. Nothing else
in that file changes.

### Tests — `ProjectionBreakdownTests.swift`
App-layer tests against an in-memory container:
- the breakdown rows returned for a seeded month sum to `projectedEndOfMonthBalance`
- row ids and order are exactly
  `currentAvailable, remainingIncome, remainingBills, remainingSpending, remainingSavings, projectedBalance`
- `simulate` with a 1_200 expense yields `impact == -1_200`, leaves `store.projection` untouched,
  and writes nothing to the store (transaction count unchanged)
- "Add as Expense" then `refresh()` moves `projectedEndOfMonthBalance` by exactly −1_200

## Done when
- [ ] build succeeds for the iPhone 17 simulator
- [ ] all tests pass
- [ ] `grep -rn "projectedEndOfMonthBalance -\|- 1200\|impact =" FlowPlan/Features/Projection/` shows
      no hand-rolled arithmetic — every figure is read from the engine's output
- [ ] tapping the hero card reaches the breakdown, and the breakdown's total matches the card
