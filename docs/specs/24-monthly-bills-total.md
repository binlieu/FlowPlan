# Codex task spec — 24 — Total row for Monthly Bills on Plan

## The gap
`PlanExpectedIncomeSection` ends with a tinted `TOTAL EXPECTED INCOME` row. The Monthly Bills
section has no equivalent, so the user cannot see what their bills come to for the month without
adding them up by hand.

## Scope
- `FlowPlan/Features/Plan/MonthlyBillsSection.swift`
- `FlowPlan/Features/Plan/PlanView.swift` (to pass the value through)
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**` — the value already exists. All 106 domain tests must
pass unchanged.

## What to add
A tinted total row at the end of the bills group, styled exactly like the income total so the two
sections read as a pair: `TOTAL MONTHLY BILLS` … `-$2,392.98`.

**Use `projection.plannedBillsTotal`.** Do not sum the rows in the view. That field is the
engine's plan-only bills total for the selected month and already accounts for recurrence — a
fortnightly bill occurring twice in a month contributes twice, which a naive sum of bill amounts
would get wrong. It is also the exact figure the Monthly Projection card shows as "Recurring
bills", so the two cannot disagree.

Show the amount as a negative, matching how the projection card presents it and how the income
total shows a positive.

When there are no bills, show the total row as `-$0` rather than hiding it, so the section's shape
is stable and it is obvious the figure is zero rather than missing.

## Tests
- the displayed total equals `projection.plannedBillsTotal` for a month with several bills
- a bill recurring twice within one month contributes twice — the case a naive row sum gets wrong
- deactivating a bill lowers the total
- with no bills the row renders zero rather than disappearing
- the total shown on Plan equals the "Recurring bills" figure on the Monthly Projection card

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] the bills total and the projection card's "Recurring bills" row always show the same number
