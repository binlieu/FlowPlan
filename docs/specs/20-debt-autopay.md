# Codex task spec — 20 — Debts need auto-pay, like bills

## The gap
`PlannedBill` has `isAutoPay`, and spec 13 added a one-tap "Mark all as paid" for overdue autopay
bills — because money on autopay has already left the account, so holding it as an unpaid
obligation overstates available cash and understates spending.

`Debt` has no equivalent. Spec 16 stated "autopay bulk-settle stays bills-only; debt payments are
settled individually", which was wrong: a mortgage or car loan on autopay is the common case. An
overdue debt payment therefore reduces the projection correctly but never reaches `Spent`, so
`AVAILABLE THIS MONTH` keeps counting money already taken.

## Scope
- `Packages/FlowPlanDomain/Sources/FlowPlanDomain/Models/Debt.swift`
- `FlowPlan/Data/Persistence/Entities.swift`, `FinanceRepository.swift`
- `FlowPlan/Features/Plan/EditDebtView.swift`, `DebtSection.swift`
- `FlowPlan/Features/Home/UpcomingBillsSection.swift`
- `FlowPlanTests/`, domain tests

## 1. Domain
Add `public let isAutoPay: Bool` to `Debt`, mirroring `PlannedBill`. It is metadata about how the
payment is made — **it must not change any projection arithmetic**. All 102 domain tests must pass
unchanged; that is the signal this addition is inert.

Add `isAutoPay: Bool = false` to `DebtEntity` (with a default, so existing debts migrate cleanly)
and carry it through the repository mapping.

## 2. Editor and row
`EditDebtView` gains an **Auto-pay** toggle, placed with the existing "Payment is in Monthly
Bills" toggle. Give it a one-line explainer distinguishing the two, because they are easy to
confuse:

- *Auto-pay* — the payment leaves your account automatically.
- *Payment is in Monthly Bills* — the payment is already listed as a bill, so it is not counted
  again.

`DebtSection` rows show an `AUTO PAY` chip when set, matching how bills present it.

## 3. Include overdue autopay debts in the bulk-settle
`UpcomingBillsSection` currently filters the prompt to `occurrence.bill.isAutoPay`. Extend it to
include **overdue autopay debt occurrences**, settling each through
`repository.markDebtPaymentMade` at its own due date and amount.

Keep these rules exactly:
- debts marked `isPaidThroughBills` stay **excluded** — their bill is already in the list and gets
  settled as a bill; including both is the double count this whole feature guards against
- non-autopay overdue debts keep per-row **Mark as paid** only; they may genuinely be unpaid
- nothing is settled silently — the prompt stays one explicit tap, because a scheduled payment can
  fail and inventing transactions would falsify the user's history
- the prompt copy counts bills and debts together ("3 autopay payments were due")

## Tests
- adding `isAutoPay` changes no projection figure — assert a full `MonthlyProjection` equality
  between an autopay and a non-autopay debt that are otherwise identical
- an overdue autopay debt appears in the bulk-settle set; a future-dated one does not
- an overdue autopay debt marked `isPaidThroughBills` is **excluded** from the set
- settling through the prompt lowers `currentAvailableBalance` and raises `expensesPaid` by the
  payment, and leaves `projectedEndOfMonthBalance` **unchanged**
- a non-autopay overdue debt is not included in the bulk action

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` — 102 tests pass unchanged, plus the new ones
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] an overdue autopay debt can be settled from Home in one tap, and doing so moves its amount
      out of available cash and into spending
