# FlowPlan

**Know where your money goes.**

FlowPlan is a native iPhone personal finance app built around one question:

> *Based on everything I know right now, how much money will I have left at the end of this month?*

It is not accounting software. It is a monthly financial planning app whose signature feature —
**Projected End of Month** — is the hero of the home screen, is explained line by line when you
tap it, and recalculates the instant anything relevant changes.

## Requirements

| | |
|---|---|
| Xcode | 26.0 or later (developed on 26.6) |
| Swift | 6.0 toolchain or later (developed on 6.3.3) |
| Minimum iOS | 18.0 |
| Dependencies | none — Apple frameworks only |

## Getting started

```bash
open FlowPlan.xcodeproj
```

Select the **FlowPlan** scheme and any iPhone simulator, then run. Sample data for August 2026
can be switched on in Settings; it is off by default and never touches production behaviour.

## Architecture

```
Packages/FlowPlanDomain/   pure Swift financial core — Foundation only
FlowPlan/App/              app entry, AppState (selected month, preferences), ProjectionStore
FlowPlan/Data/             SwiftData entities, repositories, seed data
FlowPlan/Features/         Home · Projection · Transactions · Plan · Insights · Settings
FlowPlan/Shared/           reusable components, formatting, extensions
FlowPlanTests/             repository, mapping and store tests
```

The financial engine lives in a **separate Swift package that imports `Foundation` and nothing
else** — no SwiftUI, no SwiftData. That is enforced by the module boundary rather than by
convention, which means:

- it is testable with `swift test` in seconds, with no simulator and no store,
- and the same engine can later drive a widget, an Apple Watch app, Shortcuts or the What-If
  simulator without the financial logic being rewritten.

Views render state and dispatch intent. They contain no arithmetic. `ProjectionStore` is the one
place the engine is called.

Full detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Why things are the way they are: [`docs/DECISIONS.md`](docs/DECISIONS.md).

## Build and test

```bash
# financial core — fast, no simulator
cd Packages/FlowPlanDomain && swift test
```

```bash
# app target
xcodebuild -scheme FlowPlan -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Features

- **Projected End of Month** — the hero number, with a full tap-through breakdown of how it was
  calculated and a plain-language interpretation
- **Safe to Spend per day** — derived from money that actually exists and is not committed
- **Month navigation** — every screen is month-centred and moves together
- **Transactions** — add, edit, delete, duplicate, search and filter, grouped by date
- **Plan** — expected income, recurring bills, category budgets and a savings goal; every change
  updates the projection immediately
- **What-If** — test a purchase against the same engine without saving it
- **Insights** — income vs expenses, spending by category, savings rate, month comparison
- **Face ID lock**, dark mode, Dynamic Type and VoiceOver support throughout

## Money and correctness

All amounts are `Decimal` — never `Double`. Amounts are stored as positive magnitudes with an
explicit type carrying the direction. Currency formatting is locale-aware and never assumes two
decimal places or a `$` glyph.

Actual transactions and outstanding expectations are counted in **disjoint terms**, so marking a
bill paid moves it across the boundary and leaves the projected balance unchanged. That
invariant has its own regression tests.

## Privacy

Local-first. No accounts, no servers, no bank connections, no analytics, no ads. Financial values
are never written to logs, and preferences — not financial data — are the only thing in
`UserDefaults`. Face ID is optional and off by default.

## Current limitations

- Manual entry only; no bank or card synchronisation
- Single currency at a time, chosen in Settings
- No iCloud sync yet — the data model is designed to allow it later
- Widgets, Apple Watch, Shortcuts and Siri are deliberately deferred (see `docs/master-prompt.md` §47)
