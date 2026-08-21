# Codex task spec — 39 — Rebuild Settings on ScrollView + GroupedList, like Plan

## Why
Settings is a native SwiftUI `Form`. Its grouped-card appearance and horizontal margins come from
the platform, and those margins are not design tokens. Four attempts (specs 36, 37, 38 and two
manual fixes) have failed to make a `Form` match the other tabs: each one fixed the title, the
card inset or the row grouping while breaking one of the others.

Plan already produces exactly the required appearance using `ScrollView` + `GroupedList`. The
owner's decision is to rebuild Settings the same way, so consistency comes from **using the same
components**, not from re-implementing a `Form`'s internals.

## Requirements

### Structure
Replace `Form` with the structure `PlanView` uses: a `ScrollView` containing `ScreenHeader`, then
sections built from `SectionHeading` + `GroupedList`. Same for the subscreens —
`AccountsSettingsView`, `CategoriesSettingsView`, `DataSettingsView` — and `ProjectionMethodView`.

Delete `designSystemForm()` and `designSystemRows()` once nothing uses them, along with any
`Form`-specific plumbing they needed. Leave `designSystemList()` if `TransactionsView` still needs
it; that screen is a `List` for its swipe actions and is working correctly.

### Every control must keep working
This is the risk of this change. `Form` provides behaviour a `ScrollView` does not, so verify each
of these explicitly and report on them individually:

- **Text field** — the name field must accept input, and the keyboard must not obscure it. Add
  scroll-dismisses-keyboard behaviour if `Form`'s implicit handling is lost.
- **Pickers** — Currency, Appearance and Auto-lock. A `Picker` outside a `Form` defaults to a
  different style; set `.pickerStyle(.menu)` explicitly so each still presents a menu rather than
  pushing a new screen or rendering as a segmented control.
- **Toggles** — Haptic feedback, Record auto-pay, Carry balance forward, Notifications, Face ID.
  Face ID must stay disabled when biometrics are unavailable, with its explanatory footer intact.
- **Navigation links** — Accounts, Categories, Data, Projection method must still push.
- **Section footers** — the notification and Face ID explanations must remain associated with
  their sections.
- **Destructive actions** in Data — erase and import/export confirmations must be unchanged.

### Appearance
- Title at `Spacing.lg` from each edge, matching the other four tabs.
- Section cards at `Spacing.lg`, rows grouped into one card per section with hairline separators
  and rounded first/last corners — i.e. whatever `GroupedList` already does on Plan.
- Light and dark both correct. Dynamic Type to the largest accessibility size without clipping.
- VoiceOver order and labels preserved; the header stays the first element.

## Verify by measurement, and report the numbers
For Home, Activity, Plan, Insights and Settings, report the left edge in points of the title and
of the first card. All ten must be `Spacing.lg`, allowing for border antialiasing.

Then confirm, item by item, that each control listed above still works. If you cannot verify one,
say which rather than implying it was checked.

## Scope
- `FlowPlan/Features/Settings/**`
- `FlowPlan/Shared/DesignSystem/NativeContainerStyle.swift` — removing dead Form plumbing

Do NOT touch `Packages/FlowPlanDomain/**`, `ProjectionStore`, the repository, or any displayed
value. All 106 domain and 135 app tests must pass unchanged.

## Done when
- [ ] Settings and its subscreens use `ScrollView` + `GroupedList`, no `Form`
- [ ] rows group into one card per section
- [ ] the ten measurements are all `Spacing.lg`
- [ ] every control in the list above is confirmed working
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
