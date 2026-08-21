# Codex task spec — 36 — Native containers add horizontal margins the design system already owns

## The defect
The Settings title sits ~40pt from the screen edge; Insights' sits at ~24pt. Settings' section
headers are at ~35pt while its own cards are at ~20pt, so nothing on that screen lines up with
anything else.

Cause: `Form` and grouped `List` apply their own horizontal scroll-content margins. A design-system
component placed inside one — `ScreenHeader`, which adds `.padding(.horizontal, Spacing.lg)` —
therefore gets the container's margin **plus** its own. `listRowInsets` cannot cancel a scroll
content margin, so the two stack.

**This is the third occurrence of one pattern:**
1. `ListRow` inside `GroupedList` — both padded, 64pt total (spec 35)
2. Activity's `.listStyle(.insetGrouped)` — style margins plus row insets, ~40pt (fixed)
3. `ScreenHeader` inside `Form` — container margin plus component padding, ~40pt (this spec)

Fix the class, not the third instance.

## The rule to establish
**The design system owns horizontal placement. Native containers contribute zero horizontal
margin.** Every element positions itself with `Spacing` tokens, so a component renders identically
whether it is inside a `Form`, a `List`, or a `ScrollView`.

## Fix
1. In `DesignSystemNativeContainer` (backing `designSystemForm()` and `designSystemList()`), zero
   the horizontal scroll-content margins, alongside the existing top handling.
2. Audit what then relies on those margins for its position — Settings' section cards, its section
   headers and footers, and the subscreens (Accounts, Categories, Data). Each must set its own
   horizontal placement with `Spacing` tokens so it lands where it does today: cards at
   `Spacing.lg` from the edge, matching Home and Plan.
3. `ScreenHeader` keeps its own `.padding(.horizontal, Spacing.lg)` and needs no change once the
   container stops contributing.

Do not solve this by subtracting the container's margin with negative padding, and do not special-
case Settings. Both leave the class of bug in place for the next screen.

## Verify by measurement
Report the left edge, in points from the screen edge, of each of these — they must all be
`Spacing.lg` (24pt), allowing for border antialiasing:

- the title on Home, Activity, Plan, Insights and Settings
- the first card or grouped container on each of those five tabs
- Settings' section headers, and the first row in Accounts, Categories and Data

If any cannot reach 24pt, say which and why rather than adjusting tokens to make the number come
out.

## Scope
- `FlowPlan/Shared/DesignSystem/NativeContainerStyle.swift`
- `FlowPlan/Features/Settings/**`
- `FlowPlan/Features/Transactions/TransactionsView.swift` if it relies on the same margins

Do NOT touch `Packages/FlowPlanDomain/**` or any displayed value. All 106 domain and 135 app tests
must pass unchanged.

## Done when
- [ ] all five tab titles sit at the same distance from the screen edge
- [ ] Settings' cards, headers and footers align with its title's column
- [ ] no negative padding is used to cancel a container margin
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
