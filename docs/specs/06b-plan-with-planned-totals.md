# Codex task spec — 06b — Expose planned totals, then build Plan

You correctly refused to build the projection card from `remainingBills` /
`projectedVariableSpending`, whose semantics differ. The domain change is **authorised**. Do it
first, then build Plan exactly as `docs/specs/06-plan.md` describes.

## Part 1 — domain change (do this first, keep it minimal)

### Scope
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/ProjectionModels.swift`
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Calculations/MonthlyProjectionEngine.swift`
- `Packages/FlowPlanDomain/Tests/FlowPlanDomainTests/MonthlyProjectionEngineTests.swift`

Add three stored properties to `MonthlyProjection`, populated from the values the engine already
computes locally at lines ~92–98. This exposes existing arithmetic; it does **not** change any
result.

```swift
/// Plan-only totals: what the plan says should happen this month, ignoring what actually has.
/// These are the inputs to `plannedEndOfMonthBalance`, surfaced so a view can show the plan
/// breakdown without recomputing it. Do not confuse them with the live remaining-obligation
/// figures — `remainingBills` is what is still owed, `plannedBillsTotal` is what was planned.
public let plannedIncomeTotal: Decimal
public let plannedBillsTotal: Decimal
public let plannedSpendingTotal: Decimal
```

Assign from `plannedIncome`, `plannedBills` and `plannedBudgets` respectively. The purity rule
still applies: `Foundation` only, no `Date()`, all `Sendable`, `Decimal` for money.

**Invariant to add as a test:**
`startingBalance + plannedIncomeTotal − plannedBillsTotal − plannedSpendingTotal − savingsTarget
== plannedEndOfMonthBalance`, asserted in at least three scenarios including one with no plan at
all and one with multi-occurrence recurrences (a semi-monthly salary must contribute twice).

Also assert `plannedBillsTotal != remainingBills` in a scenario where a bill has been paid, so
the distinction is pinned by a test rather than by a comment.

All 69 existing domain tests must still pass unchanged. `cd Packages/FlowPlanDomain && swift test`.

## Part 2 — build Plan

Follow `docs/specs/06-plan.md` in full, with the projection card now reading:

| Row | Source |
|---|---|
| Expected income | `plannedIncomeTotal` |
| Recurring bills | `plannedBillsTotal` |
| Planned spending | `plannedSpendingTotal` |
| Savings goal | `savingsTarget` |
| **PROJECTED REMAINING** | `plannedEndOfMonthBalance` |

Still no arithmetic in the view. Debt remains omitted (DECISIONS.md D-014).

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` passes with the new invariant tests
- [ ] app builds for the iPhone 17 simulator with no new warnings
- [ ] all existing app tests pass, plus the new `PlanEditingTests`
- [ ] the projection card's five figures come straight from `MonthlyProjection`
