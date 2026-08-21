# Codex task spec — 38 — Form rows render as separate cards instead of one card per section

## Where this stands
Spec 37 got most of the way. Verified on the simulator:

- every tab title now sits at 24pt, including Settings ✅
- Settings' subtitle is no longer clipped ✅
- section content is inset `Spacing.lg` from both edges ✅

**Remaining defect:** each row draws its own complete rounded card with a gap beneath it, so the
Profile section renders as three separate cards — "Alex", "Currency", "Region" — instead of one
card containing three rows separated by hairlines. Some adjacent rows in Preferences do appear
joined, so the behaviour is inconsistent between sections.

## The likely cause — verify before fixing
`DesignSystemRows` computes `GroupedRowPosition(index:count:)` from
`ForEach(sections: content)` → `positionedRows(in: section.content)`. If that decomposition yields
one subview per section rather than all of a section's rows, every row is simultaneously first and
last, so each gets both top and bottom corner rounding — which matches what is on screen.

Confirm that is what is happening before changing anything; if the cause is different, fix the
actual cause and say what it was.

## Requirements
- Rows within one `Section` render as **one** card: `Radius.card` on the top corners of the first
  row and the bottom corners of the last row only, square corners between, hairline separators
  between adjacent rows, and no vertical gap between rows of the same section.
- Sections remain separated by their existing vertical spacing.
- A single-row section keeps rounding on all four corners.
- This must hold for Settings and its subscreens — Accounts, Categories, Data — and any other
  `designSystemForm()` / `designSystemList()` user.
- Keep using `GroupedList`'s shared shape logic. Do not add a second implementation.

## Verify by measurement and by preview
- Add a preview showing a two-section form: one section with three rows, one with a single row —
  in light and dark. This is the case that is currently wrong, and a preview makes a regression
  visible without a device.
- Re-confirm the ten measurements from spec 37 still hold: the title and first card of each of
  Home, Activity, Plan, Insights and Settings at 24pt.

## Scope
- `FlowPlan/Shared/DesignSystem/NativeContainerStyle.swift`
- `FlowPlan/Shared/DesignSystem/GroupedList.swift` — shared shape logic only

Do NOT touch `Packages/FlowPlanDomain/**` or any displayed value. All 106 domain and 135 app tests
must pass unchanged.

## Done when
- [ ] a three-row section renders as one card with two internal separators
- [ ] a single-row section is rounded on all four corners
- [ ] no vertical gap between rows of the same section
- [ ] the ten 24pt measurements still hold
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
