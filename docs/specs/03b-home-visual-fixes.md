# Codex task spec — 03b — Home dashboard visual defects

## Goal
Fix eight defects found by running the app on an iPhone 17 simulator in light and dark mode.
Layout and presentation only — no changes to projection maths or data flow.

## Scope — touch ONLY these
- `FlowPlan/Features/Home/HomeView.swift`
- `FlowPlan/Features/Home/ProjectionHeroCard.swift`
- `FlowPlan/Features/Home/SafeToSpendCard.swift`
- `FlowPlan/Shared/Components/StatTile.swift`
- `FlowPlan/Shared/Components/MonthNavigationBar.swift`
- `FlowPlan/Shared/Components/EmptyStateView.swift`

Do NOT modify the domain package, `Data/`, `AppState`, `ProjectionStore`, or the Xcode project.

## Defects — all confirmed on device, fix every one

1. **Greeting is clipped on the left.** "Good afternoon, Alex" renders with the leading `G`
   sliced off at the screen edge. The greeting text is escaping its frame. Give it the same
   horizontal padding as the rest of the content and confirm the first glyph is fully visible at
   every Dynamic Type size.

2. **Stray disclosure chevron outside the hero card.** A `>` floats at the far right edge of the
   screen, vertically centred on the card and *outside* it. That is the default `NavigationLink`
   disclosure indicator. Use `.buttonStyle(.plain)` / a plain `NavigationLink` label so no
   system chevron is drawn; the card already renders its own chevron in the top-right corner.

3. **Bottom content is hidden behind the floating tab bar.** "for the 13 days left in August"
   and the "Upcoming Bills / See all" header are cut off by the tab bar. Add bottom content
   padding via `.safeAreaInset(edge: .bottom)` or equivalent so the last row is fully readable
   when scrolled to the end. Verify by scrolling to the bottom.

4. **~250pt of dead space above the greeting.** The screen opens with the status bar, a lone
   floating `+` button, then a large gap before any content. The hero card should be near the
   top. Remove the empty navigation title area (use `.navigationBarTitleDisplayMode(.inline)`
   with no title, or drop the reserved title space) and keep the `+` in the toolbar.

5. **Empty state fabricates a projection.** With no data at all the card shows `$0.00`, the
   sentence "You're projected to finish August with only $0.00 remaining", and a **Tight**
   badge. That presents an invented figure as a forecast. When
   `projection.completeness` has no income, no bills, no budget, no savings goal **and** no
   starting balance, replace the hero card body with a first-run state:
   - title "No plan for August yet"
   - message "Add your expected income to see where the month will land."
   - a primary action routing to the Plan tab
   Show no amount and no status badge in that state. Master prompt §42: never fabricate a
   financial value when the required data is unavailable.

6. **Stat tiles are invisible in light mode.** In dark mode the tiles have a clear card fill; in
   light mode they read as floating text with no container. Give `StatTile` a fill that is
   visible in both — `Color(.secondarySystemGroupedBackground)` over a
   `Color(.systemGroupedBackground)` page, or a material. Verify both appearances.

7. **Stat tile baselines misalign.** "Bills Remaining" wraps onto two lines while its siblings
   use one, so the values in that grid row sit at different heights. Make every tile in a row
   the same height (equal-height grid rows / `.frame(maxHeight: .infinity)` inside a fixed row)
   and keep the value baseline consistent. Do not fix this by truncating the label.

8. **Variance colour contradicts the status badge.** "-$400.00 vs your original plan" renders in
   red with a red down arrow, directly above a green "Healthy" badge — two opposite signals about
   the same month. The variance row is context, not an alarm: render it in `.secondary` with a
   directional SF Symbol, and reserve red for `status == .negative`. Keep the arrow so direction
   is not carried by colour.

## Verification — you cannot run the simulator, so instead
- confirm the project type-checks with warnings as errors
- add or update `#Preview`s covering: light and dark, the empty first-run state, the smallest
  and largest Dynamic Type sizes, and a long user name
- state in your final message which preview demonstrates each of the eight fixes

## Done when
- [ ] all eight defects addressed
- [ ] `grep -rnE "Color\(red:|#colorLiteral|Color\(hex" FlowPlan/` still finds nothing
- [ ] no change to any file outside the scope list
