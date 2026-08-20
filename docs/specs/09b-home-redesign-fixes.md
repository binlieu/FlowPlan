# Codex task spec — 09b — Home redesign layout defects

## Goal
Fix four layout defects found running the redesigned Home on an iPhone 17 simulator in light
and dark mode. Presentation only — no data flow or projection changes.

## Scope — touch ONLY these
- `FlowPlan/Features/Home/AvailableThisMonthCard.swift`
- `FlowPlan/Features/Home/MonthSpendingCard.swift`
- `FlowPlan/Features/Home/CashFlowBar.swift`
- `FlowPlan/Features/Home/HomeView.swift`
- `FlowPlan/Shared/Components/AmountText.swift`
- `FlowPlan/Shared/Formatting/MoneyFormatter.swift`

Do NOT modify the domain package, `Data/`, `AppState`, `ProjectionStore`, `Features/Projection`,
`Features/Transactions`, or the Xcode project.

## Defects — all confirmed on device

1. **Currency values wrap onto three lines in the hero strip.** `INCOME` renders as
   `+` / `$8,500.0` / `0` — the sign breaks onto its own line and the digits split mid-number.
   `EXPENSES` does the same. The three columns are too narrow for a full-precision currency
   string.

2. **`SPENT` / `BUDGET` / `REMAINING` values overlap each other** in `MonthSpendingCard`. The
   spent value and the budget value are drawn on top of one another and are unreadable. Same
   root cause as (1).

3. **Cash-flow legend wraps and misaligns.** The third legend item renders as `Estimated` /
   `savings` / `$4,057.02` across three lines while its siblings use two, so the legend row is
   ragged.

4. **Bottom content is hidden behind the floating tab bar again.** The `QUICK ADD` button labels
   are cut off by the tab bar. This is a regression — spec 03b fixed exactly this on the previous
   Home and the rewrite dropped it. Restore the bottom `.safeAreaInset` / content padding and
   verify by scrolling to the very end.

## How to fix 1–3 — compact money, not smaller columns
The handoff shows `+$8,500`, `-$5,079.50`, `+$1,500` — **cents are omitted when they are zero**
and shown when they are not. Add a `compact` style to `MoneyFormatter`:
- zero fraction digits when the amount has no fractional part, two when it does
- the sign stays attached to the number and must never break onto its own line

Then in the strips:
- render sign + amount as a **single `Text`**, never a stacked `HStack` of sign and value
- `.lineLimit(1)` with `.minimumScaleFactor(0.6)` so large Dynamic Type shrinks rather than wraps
- give the three columns equal width and let them compress together

Keep full precision (with cents) for the hero amount, the breakdown screen and transaction rows —
only the compact column strips and the legend change. Accessibility labels must keep speaking
the **exact** amount including cents, regardless of what is displayed.

## Done when
- [ ] builds for the iPhone 17 simulator with no new warnings
- [ ] all 86 tests still pass
- [ ] no value in any three-column strip wraps or overlaps at default Dynamic Type
- [ ] at the largest accessibility text size, values scale down rather than colliding
- [ ] the `QUICK ADD` labels are fully visible when scrolled to the bottom
- [ ] verified in both light and dark
