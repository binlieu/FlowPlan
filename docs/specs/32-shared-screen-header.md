# Codex task spec — 32 — Screen headers sit at different heights per tab

## The defect
The top padding above a screen's title differs by tab. Home and Plan apply
`.padding(.top, 24)`; Activity, Settings and Insights do not and fall back to default spacing, so
their titles sit noticeably lower. Switching tabs makes the header jump.

There is no shared header component — each screen builds its own title block, so they were always
free to diverge.

## Fix — one component, used by all five tabs
Create `FlowPlan/Shared/DesignSystem/ScreenHeader.swift`:

```swift
/// The title block at the top of every tab. Owns the title, optional small-caps subtitle and
/// the top padding, so headers cannot drift apart between screens again.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil        // rendered in small caps
    var trailing: AnyView? = nil       // optional toolbar-style controls, as Activity needs
}
```

It owns the large bold title in `Palette.ink`, the small-caps subtitle in `Palette.inkSecondary`,
horizontal padding and the top padding. **Home's current spacing is the reference** — match it
exactly, so Home does not move.

Adopt it in:
- `HomeView` — greeting as title, tagline as subtitle
- `PlanView` — "Plan", month as subtitle
- `TransactionsView` — "Activity"
- `InsightsView` — its existing title
- `SettingsView` — "Settings", "PROFILE, PREFERENCES & DATA" as subtitle

Remove the now-duplicated `.padding(.top, 24)` and per-screen title blocks. Any screen with
trailing controls (Activity's filter and add buttons) passes them through `trailing` rather than
positioning them separately, so their vertical alignment with the title is also consistent.

## Scope
- `FlowPlan/Shared/DesignSystem/ScreenHeader.swift` (create)
- the five screen files above

Do NOT touch `Packages/FlowPlanDomain/**`, any displayed value, or the tab bar. Presentation only
— all 106 domain and 135 app tests must pass unchanged.

## Constraints
- Home's header must be pixel-identical before and after; it is the reference, not a thing to
  adjust.
- Dynamic Type through the largest accessibility size: the header must grow without clipping and
  without changing its top padding.
- Light and dark both correct.
- The title stays the first element in the reading order for VoiceOver on every screen.

## Tests
Previews only:
- `ScreenHeader` with and without a subtitle, with and without trailing controls
- a preview stacking all five tab headers, so any future divergence is visible at a glance

## Done when
- [ ] all five tabs render their title at the same distance from the top
- [ ] `grep -rn "padding(.top, 24)" FlowPlan/Features/` finds nothing — the padding lives in the component
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
