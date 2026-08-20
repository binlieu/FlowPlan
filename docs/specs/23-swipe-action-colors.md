# Codex task spec — 23 — Swipe action colours are too bright and off-palette

## The defect, reported on a device in dark mode
The "Mark as received" swipe action reads as too bright, and other swipe actions do not match the
design palette.

Two causes:

1. **A foreground token used as a fill.** `Palette.accent` is `#416180` in light and `#B5D9FD` in
   dark — it inverts because it is meant for *text and glyphs*. Swipe actions apply it with
   `.tint(Palette.accent)`, so in dark mode the capsule fill is a near-white blue: glaring, and
   with poor contrast against its own label.
2. **Off-palette colours.** `FlowPlan/Features/Transactions/TransactionsView.swift:151,159` use
   raw `.blue` and `.indigo`, which belong to no part of the design.

## Fix — add fill tokens, then use them everywhere
### 1. New palette tokens
The design system has foreground colours but no fills. Add colour sets to the asset catalog and
expose them on `Palette`:

| Token | Light | Dark | Use |
|---|---|---|---|
| `accentFill` | `#416180` | `#2F4B66` | primary action fill (confirm, mark paid/received) |
| `onAccentFill` | `#FFFFFF` | `#EEF3F8` | label on `accentFill` |
| `neutralFill` | `#6B6E70` | `#3A4249` | secondary action fill (edit, duplicate) |
| `destructiveFill` | `#B3261E` | `#8C1D18` | destructive action fill (delete) |

The dark values are **deliberately darker than the light ones**, not inverted — a fill sits behind
a light label in dark mode, so it must stay dark. That is the mistake being fixed; do not derive
these from `accent`.

### 2. Apply them
- `.tint(Palette.accentFill)` on Mark as received / Mark as paid / Mark payment made.
- `.tint(Palette.neutralFill)` on Edit and Duplicate.
- `.tint(Palette.destructiveFill)` on Delete — replacing `.red` where used.
- Replace the raw `.blue` and `.indigo` in `TransactionsView`.
- Ensure swipe action labels render in `onAccentFill` where the platform does not already do so.

Audit the whole app for `.tint(` and `foregroundStyle(` with a system colour literal
(`.blue`, `.indigo`, `.green`, `.red`, `.orange`) and replace each with the matching token, except
where a system semantic colour is genuinely correct (for example `.red` on a destructive
*text* button in a confirmation dialog). List anything you deliberately leave alone.

### 3. Contrast
Every fill/label pair must reach at least 4.5:1 in both appearances. State the computed ratios for
each pair in your final message so they can be checked rather than assumed.

## Tests
Colour cannot be meaningfully unit-tested; add previews instead:
- a preview of every swipe action in light and dark, with the row revealed
- a preview of the transaction row swipe set in both appearances

## Done when
- [ ] `grep -rnE "\.tint\((\.blue|\.indigo|\.green|\.orange)\)" FlowPlan/` finds nothing
- [ ] no swipe action uses `Palette.accent` as a fill
- [ ] `cd Packages/FlowPlanDomain && swift test` — 106 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
