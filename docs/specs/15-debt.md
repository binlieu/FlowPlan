# Codex task spec — 15 — Debt, with payments that end when the debt is paid off

Lifts the last D-014 deferral. **This is the highest-risk change in the product**: it adds a
second reconciliation rule to the projection engine, alongside the bill-settlement rule in D-006.
Treat the engine work as the main task and the UI as the easy part.

Design reference (local, git-ignored): `docs/design/handoff/screens/05-plan-debt.png`, transcribed
below. Build from this text.

## The two rules that make this dangerous

**Rule A — a debt payment may already be a bill.** The handoff labels each debt either
`In monthly bills` or `Counted separately`, and totals only the latter as
`OUTSIDE MONTHLY BILLS $505`. A mortgage is usually already in Monthly Bills; counting its
payment again as a debt payment would subtract it twice. Only debts marked *not* in monthly bills
contribute a payment to the projection.

**Rule B — payments stop when the balance reaches zero.** A debt is not an open-ended recurrence.
A car loan finishing in March 2027 must contribute nothing to April 2027. Every month's
projection must ask whether this debt still owes anything *in that month*.

## Part 1 — domain (do this first, and completely)

Scope: `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/Debt.swift` (create),
`.../Calculations/DebtSchedule.swift` (create),
`.../Calculations/MonthlyProjectionEngine.swift`, `.../Models/ProjectionModels.swift`,
and matching tests. Purity rules unchanged: `Foundation` only, no `Date()`, `Sendable`, `Decimal`.

```swift
public struct Debt: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let currentBalance: Decimal      // positive; what is still owed
    public let annualInterestRate: Decimal  // e.g. 0.0649 for 6.49% APR; may be .zero
    public let monthlyPayment: Decimal      // positive
    public let category: String
    /// True when this debt's payment is already represented in Monthly Bills. Such a debt is
    /// shown for tracking but contributes NOTHING to the projection — the bill already does.
    public let isPaidThroughBills: Bool
    public let isActive: Bool
}
```

### `DebtSchedule` — amortisation, and the trap in it
A pure helper answering, for a given debt and month:

- `remainingPayments(for:)` — how many payments remain until the balance clears
- `payoffMonth(for:startingIn:)` — the `MonthKey` in which the final payment falls
- `paymentDue(for:in:)` — the amount due in a specific month: the normal `monthlyPayment`, or the
  smaller final payment when the remaining balance is less than a full payment, or `.zero` once
  the debt is paid off

Amortise monthly: `interest = balance × (annualInterestRate / 12)`,
`principal = payment − interest`, `balance −= principal`.

**Guard the non-amortising case.** If `monthlyPayment <= interest`, the balance never falls and
any loop computing a payoff runs forever. Detect it, return a `neverAmortises` state, and cap any
iteration at 600 months (50 years) regardless. A test must cover a payment below the interest
charge. This is the one bug in this feature that can hang the app.

Round money to 2 dp with `NSDecimalRound` at each step so a long schedule does not drift.

### Engine changes
Add to `ProjectionInput`: `public let debts: [Debt]`.

Add to `MonthlyProjection`:
```swift
public let debtPaymentsDue: Decimal      // due this month, excluding isPaidThroughBills
public let debtPaymentsMade: Decimal     // settled by linked transactions this month
public let remainingDebtPayments: Decimal
```

New rule, numbered and commented like the others:

> **Rule 19.** For each active debt with `isPaidThroughBills == false`, the payment due in this
> month comes from `DebtSchedule.paymentDue`. A payment is settled by an `.expense` transaction
> carrying `settlesDebtID`, matched in date order exactly as bills are. `remainingDebtPayments`
> is the sum of unsettled dues. Debts with `isPaidThroughBills == true` contribute zero — their
> money is already counted in `remainingBills`.

Add `settlesDebtID: UUID?` to `TransactionSnapshot`, alongside the existing settle links.

Then:
- `projectedEndOfMonthBalance` subtracts `remainingDebtPayments` as well
- `plannedEndOfMonthBalance` subtracts the month's total scheduled debt payments
- `spendableRemaining` subtracts `remainingDebtPayments` — a debt payment is a committed
  obligation, exactly like a bill, so safe-to-spend must exclude it
- `breakdown` gains a `remainingDebt` row **between** `remainingBills` and `remainingSpending`,
  labelled "Debt payments", stored negative. The rows must still sum to the total.

### Domain tests — all 87 existing tests must still pass unchanged
- a debt marked `isPaidThroughBills` contributes **zero** to every projection figure — the
  double-counting guard, and the single most important test in this spec
- a debt not in bills reduces `projectedEndOfMonthBalance` by its monthly payment
- settling a debt payment moves it from `remainingDebtPayments` to `debtPaymentsMade` and leaves
  `projectedEndOfMonthBalance` **unchanged**
- a debt whose balance is smaller than one payment yields exactly the remaining balance, not a
  full payment
- a debt paid off in March contributes nothing in April, and `payoffMonth` reports March
- zero APR amortises purely by principal and reaches zero in `ceil(balance / payment)` months
- a payment at or below the monthly interest reports `neverAmortises` and does not hang
- breakdown rows still sum to `projectedEndOfMonthBalance` with debts present

## Part 2 — app layer
`DebtEntity` in `Entities.swift` mirroring `Debt`, registered in the schema. Repository CRUD plus
`markDebtPaymentMade(debtID:amount:on:)` following the same shape and duplicate guard as
`markBillPaid`. Settling a payment must also reduce the stored `currentBalance`.

## Part 3 — Plan screen, per the handoff
A `Debt` section between Monthly Bills and Spending Budget:

- One row per debt: name, `{APR}% APR` secondary, the balance remaining on the right, a progress
  bar showing percent paid off against the original balance, and `{n}% paid off`.
- Under each, the status label the handoff uses: **`In monthly bills`** or
  **`Counted separately`** — this is the double-counting mechanism made visible, so it must be
  prominent, not a footnote.
- A section total row: `OUTSIDE MONTHLY BILLS` … the sum of payments actually entering the
  projection.
- Each row also shows the payoff: `{n} payments left · paid off {Month Year}`, or a clear
  "Payment does not cover interest" warning for the non-amortising case.
- Editor: name, balance, APR, monthly payment, category, the in-bills toggle (with a one-line
  explanation of what it does to the projection), and Active.

Add the `Debt payments` row to `MonthlyProjectionCard` — spec 06 deliberately omitted it while
debt was deferred. The card's rows must still sum to its total.

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` — all 87 prior tests pass plus the new ones
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] a debt marked in-bills changes no projection figure whatsoever
- [ ] no loop over an amortisation schedule can run unbounded
- [ ] `docs/DECISIONS.md`: D-014 closed, and a new D-018 recording how debt avoids double counting
