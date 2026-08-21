# Codex task spec — 34 — Activity is the one screen that skipped GroupedList

## The defect
Spec 33 created `GroupedList` and adopted it in eight files — Home's expected-income and bills
sections, all five Plan sections, and the projection detail. **`TransactionsView` was missed.**

Activity's rows already use the shared `ListRow`, but its container is a raw `List` with `Section`s
and per-row `listRowBackground`, so each transaction renders as a separate floating capsule
instead of rows inside one grouped card. Every other tab groups its rows; Activity does not.

Its header-to-content spacing also differs: `TransactionsView.swift:51` applies
`.listRowInsets(EdgeInsets())` — an ad-hoc zero inset that no other screen uses — so the gap
between the title and the first content differs from Home, Plan, Insights and Settings.

## Scope
- `FlowPlan/Features/Transactions/TransactionsView.swift`
- `FlowPlan/Shared/DesignSystem/GroupedList.swift` — only if a parameter must be added
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**`, `TransactionRow.swift`'s content, or any displayed
value. Presentation only — all 106 domain and 135 app tests must pass unchanged.

## Fix

### 1. Group the rows
Render each day's transactions inside `GroupedList`, exactly as `MonthlyBillsSection` and
`PlanExpectedIncomeSection` do: one bordered container per day section, hairline separators
between rows, correct first/last row corner treatment. The day header (`SAT, AUG 29` and its
net total) stays **above** its group, matching how Plan's section headings sit above their groups.

**Swipe actions must keep working** inside the grouped container — edit, duplicate and delete are
the reason this screen uses `List` at all. If `GroupedList` cannot host swipe-enabled rows, add
the capability to `GroupedList` rather than exempting Activity. Exempting it is what produced
this defect.

### 2. Normalise header spacing
Remove the ad-hoc `.listRowInsets(EdgeInsets())`. Activity's spacing from title to first content
must match the other tabs. `ScreenHeader` already owns the top padding; anything below it should
use the same `Spacing` tokens the other screens use, not a bespoke zero inset.

Compare against Plan, which also has a header, a month bar and grouped content — Activity should
be indistinguishable from it in vertical rhythm.

### 3. Check the rest of the screen
While there: the search field and the filter/add controls should also sit on the same horizontal
insets as the grouped content, so the left edges line up down the whole screen.

## Tests
Previews:
- Activity with several day sections, light and dark
- Activity beside Plan at the same scale, so vertical rhythm divergence is visible
- Activity at the largest Dynamic Type size

## Done when
- [ ] `grep -c "GroupedList" FlowPlan/Features/Transactions/TransactionsView.swift` is greater than zero
- [ ] `grep -n "listRowInsets(EdgeInsets())" FlowPlan/Features/Transactions/TransactionsView.swift` finds nothing
- [ ] transactions render as grouped rows in a bordered container, not separate capsules
- [ ] swipe actions, search, filtering and the month bar all still work
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
