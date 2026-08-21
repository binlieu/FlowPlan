# Codex task spec — 37 — Finish the container-margin fix: Form sections must draw their own card

## Where this stands
Spec 36 zeroed the horizontal scroll-content margins on `designSystemForm()` / `designSystemList()`,
which correctly put every tab title at 24pt. But it did not do the second half of that spec —
"audit what then relies on those margins for its position".

Settings' section cards relied on them. `DesignSystemRows` pads its **content** by `Spacing.lg`
while `listRowBackground(Palette.surface)` still fills the full row width, so with the container
margin gone the cards now span edge to edge and have lost their rounded corners.

An attempt to fix it the other way — restoring the margins and zeroing `ScreenHeader`'s own
padding — put the title at ~16pt instead of 24pt and clipped the subtitle. That direction is a
dead end: the platform's grouped margin is not a design token, and compensating for it means
hard-coding a magic offset.

## Finish it in the direction spec 36 chose
The design system owns horizontal placement. Native containers contribute zero. So the **section
card must be drawn by us**, exactly as `GroupedList` already does for lists — same fill, same
`Radius.card`, same hairline stroke, same first/last row corner treatment.

- Give `DesignSystemRows` (or a new section-level modifier, if that is cleaner) an inset rounded
  card: `Palette.surface` fill, `Radius.card` corners on the first and last row of each section,
  hairline separators between rows, positioned `Spacing.lg` from each screen edge.
- Reuse `GroupedList`'s row-shape logic rather than writing a second copy. If it needs to be
  extracted to be shared, extract it — a second implementation of the same corner treatment is how
  the three container bugs started.
- `ScreenHeader` keeps its own `Spacing.lg` padding and needs no change.

Applies to Settings and its subscreens — Accounts, Categories, Data — and anything else using
`designSystemForm()` or `designSystemList()`.

## Verify by measurement, and report the numbers
For each of Home, Activity, Plan, Insights, Settings, report the left edge in points of:
- the screen title
- the first card or grouped container

All ten must be 24pt, allowing for border antialiasing. Also confirm Settings' subtitle is not
clipped and that its section cards have rounded corners on their first and last rows.

If any value cannot reach 24pt, report which and why. Do not adjust `Spacing.lg`, and do not use
negative padding.

## Scope
- `FlowPlan/Shared/DesignSystem/NativeContainerStyle.swift`
- `FlowPlan/Shared/DesignSystem/GroupedList.swift` — only to extract shared shape logic
- `FlowPlan/Features/Settings/**`

Do NOT touch `Packages/FlowPlanDomain/**` or any displayed value. All 106 domain and 135 app tests
must pass unchanged.

## Done when
- [ ] Settings' section cards are inset `Spacing.lg` with rounded first/last corners
- [ ] all five titles and all five first-cards measure 24pt
- [ ] Settings' subtitle is not clipped
- [ ] one implementation of the row corner treatment, not two
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
