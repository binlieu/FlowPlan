# Codex task spec — 40 — Plan total rows should read like PROJECTED REMAINING

## The change
`PlanTotalRow` renders as a solid `Palette.accentLight` bar — a heavy filled block that dominates
each Plan section. The `PROJECTED REMAINING` row inside `MonthlyProjectionCard` states the same
kind of figure far more quietly: a hairline rule above it, a small-caps label in `Palette.accent`,
the amount in `Palette.ink`, and **no fill at all**.

The owner wants every Plan total to read like `PROJECTED REMAINING`.

Affects all five, since they share one component: `TOTAL EXPECTED INCOME`, `TOTAL MONTHLY BILLS`,
`OUTSIDE MONTHLY BILLS`, `TOTAL SPENDING BUDGET`, `TOTAL SAVINGS GOAL`.

## What to do
Restyle `PlanTotalRow` to match `MonthlyProjectionCard`'s total row exactly:

- remove `.background(Self.accentFill)` and the `accentFill` helper
- a 1pt `Palette.hairline` rule above the row, separating it from the rows it totals
- label: `smallCapsTypography()` in **`Palette.accent`** (currently `inkSecondary`)
- amount: `valueTypography()`, `monospacedDigit()`, `Palette.ink` — unchanged
- keep the existing sign handling, including zero rendering without a sign

**Extract the shared row rather than styling two things the same way.** `MonthlyProjectionCard`
should use `PlanTotalRow` for its `PROJECTED REMAINING` row, so there is one implementation. Two
copies of the same total row is exactly how the Plan totals drifted apart before, and how the card
containers multiplied.

If the projection card's row needs something `PlanTotalRow` lacks, add the parameter rather than
forking.

## Constraints
- The total must still be visually distinct from the rows above it — the hairline and the accent
  label carry that now instead of the fill. Confirm it still reads as a total at a glance in both
  appearances.
- Light and dark correct; Dynamic Type to the largest accessibility size without clipping.
- Do not change any value, sign, or accessibility label.

## Scope
- `FlowPlan/Shared/DesignSystem/PlanTotalRow.swift`
- `FlowPlan/Features/Plan/MonthlyProjectionCard.swift`
- the five Plan sections only if the call sites need adjusting

Do NOT touch `Packages/FlowPlanDomain/**`. All 106 domain and 135 app tests must pass unchanged.

## Tests
Previews:
- all five Plan totals stacked, light and dark
- the projection card, confirming its total row is unchanged in appearance
- largest Dynamic Type

## Done when
- [ ] no Plan total has a filled background
- [ ] `grep -rn "accentFill" FlowPlan/Shared/DesignSystem/PlanTotalRow.swift` finds nothing
- [ ] `MonthlyProjectionCard` uses `PlanTotalRow`; there is one total-row implementation
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
