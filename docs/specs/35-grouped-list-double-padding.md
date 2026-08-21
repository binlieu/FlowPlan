# Codex task spec — 35 — GroupedList and ListRow both pad, so titles truncate

## The defect
After Activity adopted `GroupedList` (spec 34), transaction titles truncate —
"Miscellaneous expense" renders as "Miscellaneous expe…" where it previously fit.

Cause: the two components each apply their own horizontal padding.

- `ListRow.contentInsets` defaults to `Spacing.md` on all four edges — `ListRow.swift:57`
- `GroupedList`'s row wrapper adds `.padding(.horizontal, Spacing.md)` — `GroupedList.swift:143`

A `ListRow` inside a `GroupedList` therefore carries **32pt of horizontal padding per side**, 64pt
total, leaving the title far less room than the design intends. Every screen using both is
affected; Activity just made it visible because its titles are the longest.

## Fix — one owner for row padding
Decide which component owns horizontal row padding and make it the only one that applies it.
**`GroupedList` should own it**, because it also owns the border, background, separators and
corner treatment — the padding belongs with the container that draws the edges.

- Remove the horizontal inset from `ListRow`'s default `contentInsets` when it is hosted inside a
  `GroupedList`. Prefer an explicit mechanism over a guess: either an environment value the
  `GroupedList` sets and `ListRow` reads, or a `contentInsets` value the group passes down. Do not
  rely on the caller remembering to pass different insets — that is how the two drifted apart.
- Keep `ListRow`'s standalone default unchanged, so a `ListRow` used outside a group still pads
  itself.
- Verify the vertical rhythm does not change: rows should keep their current height.

`ProjectionDetailView` and `TransactionsView` put non-`ListRow` content into `GroupedList` and
depend on the wrapper's padding — they must be unaffected.

## Verify by measurement, not by eye
Report the resulting available title width before and after, and confirm
"Miscellaneous expense" fits on one line at default Dynamic Type on an iPhone 17.

If it still does not fit after removing the duplication, say so rather than shrinking the type or
tightening the design tokens — the next step would be a product decision about long titles, not a
silent squeeze.

## Scope
- `FlowPlan/Shared/DesignSystem/ListRow.swift`
- `FlowPlan/Shared/DesignSystem/GroupedList.swift`
- call sites only if the chosen mechanism requires it

Do NOT touch `Packages/FlowPlanDomain/**` or any displayed value. All 106 domain and 135 app tests
must pass unchanged.

## Tests
Previews:
- a `GroupedList` of `ListRow`s with long titles, light and dark
- the same rows standalone outside a group, confirming their padding is unchanged
- largest Dynamic Type, confirming the accessibility layout still stacks correctly

## Done when
- [ ] a `ListRow` inside a `GroupedList` has horizontal padding applied exactly once
- [ ] "Miscellaneous expense" is not truncated at default Dynamic Type
- [ ] rows outside a group are visually unchanged
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all 135 app tests pass
