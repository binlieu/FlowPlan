# Codex task spec — 25 — Plan total rows are three copies and have drifted

## The defect, reported on a device
`OUTSIDE MONTHLY BILLS` in the Debt section does not look like `TOTAL MONTHLY BILLS` or
`TOTAL EXPECTED INCOME`.

Cause: each section builds its own total row. Income and bills both use
`.background(Palette.accentLight)`; the debt total does not, so it renders untinted. There is no
shared component, so the three were always free to drift — and did.

## Fix — one component, used by all of them
Create `FlowPlan/Shared/DesignSystem/PlanTotalRow.swift`:

```swift
/// The tinted summary row that closes a Plan section. Every Plan total uses this — income,
/// bills, debt and any added later — so they cannot drift apart again.
struct PlanTotalRow: View {
    let label: String          // rendered in small caps
    let amount: Decimal
    var signed: Bool = true    // debt/bills show negative, income positive
}
```

It owns the small-caps label, `Palette.accentLight` fill, amount typography and padding — every
visual decision, so a caller cannot restyle it.

Replace the hand-rolled rows in `PlanExpectedIncomeSection`, `MonthlyBillsSection` and
`DebtSection` with it. The rendered result for income and bills must be **unchanged**; only the
debt row changes appearance.

Keep each section's own wording — `TOTAL EXPECTED INCOME`, `TOTAL MONTHLY BILLS`,
`OUTSIDE MONTHLY BILLS` — the labels are meaningfully different and should stay.

While you are there: `SpendingBudgetSection` and `SavingsGoalSection` have no total row at all.
**Do not add one** — that is a product decision the owner has not made. Note it in your final
message so it is a visible choice rather than an oversight.

## Scope
- `FlowPlan/Shared/DesignSystem/PlanTotalRow.swift` (create)
- `FlowPlan/Features/Plan/PlanExpectedIncomeSection.swift`
- `FlowPlan/Features/Plan/MonthlyBillsSection.swift`
- `FlowPlan/Features/Plan/DebtSection.swift`

Do NOT touch `Packages/FlowPlanDomain/**` or any value being displayed — this is presentation
only. All 106 domain and 120 app tests must pass unchanged.

## Tests
Styling is not unit-testable; add previews instead:
- `PlanTotalRow` in light and dark, with a positive and a negative amount, and at the largest
  Dynamic Type size
- a preview showing all three Plan totals stacked, so any future divergence is visible at a glance

## Done when
- [ ] all three Plan total rows are visually identical apart from label and sign
- [ ] `grep -rn "accentLight" FlowPlan/Features/Plan/` finds nothing — the fill lives in the component
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
