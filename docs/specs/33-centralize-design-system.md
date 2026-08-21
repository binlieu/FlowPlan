# Codex task spec — 33 — Centralize the design system; no screen bypasses it

## The problem, measured
The design system exists but is roughly a quarter adopted, so tabs drift visually:

| Symptom | Measured |
|---|---|
| raw `.font(...)` vs shared typography modifiers | **130 vs 35** |
| distinct corner radii | **4** — 12, 18, 20, 24 |
| competing card containers | **3** — `TickCard`, `SectionCard`, raw `RoundedRectangle` |
| distinct `spacing:` values | **10** — 0,4,5,6,8,10,12,14,16,18 |
| distinct `.padding(...)` values | **8+** — 4,10,12,14,16,20,28,30 |

The owner's requirement: **every tab consistent pixel by pixel, nothing bypassing the global
pattern, everything centralized and reused.**

## Approach
Work in the order below. Each phase must build and keep all tests green before starting the next,
so a failure is attributable.

### Phase 1 — Foundations
Create `FlowPlan/Shared/DesignSystem/Metrics.swift`:

```swift
/// The only spacing and radius values in the app. A literal in a view is a bug — if a value here
/// does not fit, the scale is wrong and should be changed here, not bypassed locally.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 18      // cards and grouped containers
    static let control: CGFloat = 12   // buttons, fields, small controls
    static let chip: CGFloat = 999     // fully rounded pills
}
```

Map every existing literal to the nearest token — 5→`xxs`, 6→`xs`, 10→`sm`, 14→`md`, 18/20→`lg`,
28/30→`xl`. Where a mapping changes appearance noticeably, prefer the token and note it; the goal
is one scale, not preserving every accident.

Extend `Typography.swift` so **every** text style in the app is a named modifier — audit the 130
raw `.font(` calls, group them into the smallest set that covers them, and name each by role
(`heroAmountTypography`, `rowTitleTypography`, `rowDetailTypography`, `smallCapsTypography`, …).
Do not invent styles that only differ trivially; collapse near-duplicates.

### Phase 2 — One card container
`TickCard` is the design's signature (corner crosshairs) and stays. **Retire `SectionCard` and
every raw `RoundedRectangle` container**, replacing them with `TickCard` or a plain grouped
container that `TickCard` is built from. Exactly one type may draw a card background.

### Phase 3 — Shared row and section components
These repeat across Home, Plan and Activity with slightly different implementations. Extract one
of each into `Shared/DesignSystem/`, and use them everywhere:

- **`ListRow`** — monogram/icon, title, subtitle, trailing amount, optional status chip. Covers
  bill rows, expected-income rows, debt rows and transaction rows.
- **`SectionHeading`** — the heading plus optional trailing action ("Expected Income" + "Add").
- **`GroupedList`** — the bordered container that wraps rows with hairline separators, including
  the first/last row corner treatment.
- **`EmptyStateView`** already exists — make every empty state use it, with no bespoke variants.

Where a screen genuinely needs something the component does not support, **extend the component**
with a parameter. Do not fork it or special-case at the call site.

### Phase 4 — Sweep
No view file may contain: a numeric literal in `spacing:`/`.padding(...)`/`cornerRadius`, a raw
`.font(...)`, a colour outside `Palette`, or its own card background.

## Scope
Anything under `FlowPlan/`. Do NOT touch `Packages/FlowPlanDomain/**`, the repository, the
projection engine, or any displayed value. **This is presentation only** — all 106 domain and 135
app tests must pass unchanged, which is the proof nothing behavioural moved.

## Constraints
- Light and dark both correct on every screen.
- Dynamic Type through the largest accessibility size, no clipping or overlap.
- No regression to swipe actions, filters, search, pickers, sheets or the month navigation.
- VoiceOver order and labels preserved.
- Home is the visual reference where screens currently disagree.

## Tests
Add previews, since pixel consistency is not unit-testable:
- a gallery preview rendering `ListRow`, `SectionHeading`, `GroupedList`, `PlanTotalRow`,
  `ScreenHeader`, `TickCard`, `Chip` and `EmptyStateView` together, light and dark
- all five tab headers stacked, so divergence is visible at a glance

## Done when
- [ ] `grep -rnE "spacing: [0-9]+|\.padding\([0-9]+\)|\.padding\(\.[a-z]+, [0-9]+\)|cornerRadius" FlowPlan/Features/` finds nothing
- [ ] `grep -rn "\.font(" FlowPlan/Features/` finds nothing
- [ ] `grep -rn "SectionCard\|RoundedRectangle" FlowPlan/Features/` finds nothing
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
- [ ] report which literals you remapped and anything you deliberately left alone
