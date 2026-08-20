# FlowPlan Project Status

Updated: 2026-08-19

## Completed

- [x] Specs 01–10, including the 10a correctness pass and 10b presentation,
  architecture, and accessibility pass
- [x] Pure `FlowPlanDomain` projection, recurrence, reconciliation, What-If, and
  structured-insight engines
- [x] SwiftData persistence and repositories, app state, and authoritative
  `ProjectionStore`
- [x] Home, projection detail, What-If, transactions, Plan, Insights, Settings,
  Face ID lock, sample data, import, and export flows
- [x] Centralised currency presentation and Decimal-based financial calculations
- [x] Accessibility and Dynamic Type fixes from the second QA pass

## Deferred Post-MVP

- Debt modelling and its bill-reconciliation rules
- Account management beyond the existing transaction account field
- iCloud sync
- Home-screen and lock-screen widgets

## Known Open Issues

- QA 1.5: failed repository writes do not use a repository-wide rollback strategy.
- QA 1.6: creating a month budget override is not yet one atomic transaction.
- QA 2.8: fixed — compact formatting now asks the system for the currency's own
  fraction digits instead of assuming two.
- QA 1.8: chart/layout geometry intentionally converts Decimal values to floating
  point; the trapping savings-slider integer conversion is now clamped.
- QA 2.2: Plan budget rows still aggregate category spending during body evaluation.
- QA 2.5: the savings pace insight does not yet have calendar-based pace evidence.
- QA 2.8: compact money formatting still assumes two fractional digits.

These items are deferred under D-016 rather than addressed with isolated fixes.

## Build Status

- PASS — all app and app-test Swift sources type-check for the generic iOS 18
  device target with the checked-in `FlowPlanDomain` package.
- ENVIRONMENT BLOCKED — the exact iPhone 17 Simulator `xcodebuild` cannot run in
  the managed sandbox because CoreSimulator is unavailable and Xcode package
  manifest subprocess sandboxing is rejected. The last recorded project build
  before this pass was green.

## Test Status

- PASS — 87 `FlowPlanDomain` tests.
- 45 app tests are defined and type-check. Simulator execution is blocked by the
  environment described above.
- PASS — domain purity checks; no `USD` or `en_US` literals remain under
  `Packages/FlowPlanDomain/Sources`.
