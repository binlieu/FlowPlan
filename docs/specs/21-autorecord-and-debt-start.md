# Codex task spec — 21 — Auto-record autopay payments; give debts a start date

Two owner decisions. The first carries a real risk that must be mitigated in the implementation,
not argued with.

## Part 1 — Auto-record autopay payments on the due date

**Decision (owner).** When an auto-pay bill or debt payment's due date passes, FlowPlan records
the payment itself. No tap.

**The risk, and how to contain it.** A scheduled payment can fail — expired card, insufficient
funds, a bank holiday — and an auto-written transaction would then assert spending that never
happened. The owner accepts this trade for convenience. Contain it as follows; none of these
reverse the decision:

- **Only auto-pay items.** Non-autopay bills and debts keep the existing manual settle. They may
  genuinely be unpaid.
- **Only once the due date has passed.** Never on or before the due date.
- **Strictly idempotent.** Auto-recording runs on refresh, so it must never create a second
  settlement for an occurrence already settled — by hand or automatically. Route through the
  existing `markBillPaid` / `markDebtPaymentMade` duplicate guards; do not bypass them.
- **Identifiable and reversible.** Mark auto-recorded transactions (an `isAutoRecorded` flag on
  `TransactionEntity`, defaulted false so existing rows migrate) and show an `AUTO` chip on the
  row in Activity, so a payment that did not actually happen can be spotted and deleted.
- **A Settings toggle**, `Record auto-pay automatically`, under Preferences, defaulting **on**
  per the owner's choice, with a one-line explainer: "Auto-pay bills and debts are recorded as
  spent once their due date passes." Off restores the one-tap prompt.

Apply to **both autopay bills and autopay debts**. Leaving bills manual while debts auto-record
would repeat the asymmetry that has already produced several defects in this project.

When the toggle is on, the "Mark all as paid" prompt naturally has nothing left to offer for
autopay items; keep the prompt for overdue **non-autopay** items only.

## Part 2 — A first-payment month on debts

**The actual gap.** `firstDebtPaymentMonth = min(input.month, referenceMonth)`, so a payment is
assumed due from today onward. A debt whose payments start later — a loan signed now, first
payment in October — wrongly shows a payment due this month and next.

Note for the record: forward amortisation across months already works. `paymentDue` iterates
`0...offset` reducing the balance, so a future month already reflects the payments before it.
This change is about **when payments begin**, not about amortisation.

- Add `public let firstPaymentMonth: MonthKey?` to `Debt` (nil = starts immediately, preserving
  today's behaviour for existing debts).
- `DebtSchedule` returns `.zero` and a nil payment date for any month before it.
- The engine uses the debt's own first-payment month when set, falling back to the current
  behaviour when nil.
- `EditDebtView` gains a "First payment" month picker, defaulting to the current month, with a
  preview line: "First payment October 2026".
- `DebtSection` shows "Starts October 2026" on a debt that has not begun.

## Tests
Auto-record:
- an overdue autopay bill and an overdue autopay debt are recorded exactly once; running refresh
  repeatedly creates no duplicates
- an item already settled by hand is not recorded again
- a due date in the future records nothing
- a non-autopay overdue item records nothing
- with the toggle off, nothing is auto-recorded
- an auto-recorded settlement lowers `currentAvailableBalance` and raises `expensesPaid` by the
  amount, and leaves `projectedEndOfMonthBalance` **unchanged**
- deleting an auto-recorded transaction restores the prior figures

Start date:
- a debt with `firstPaymentMonth` in the future contributes `.zero` to every figure until then
- in its first payment month it contributes a full payment
- nil `firstPaymentMonth` behaves exactly as today — all 103 domain tests must pass unchanged

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` — 103 prior tests pass, plus the new ones
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] auto-recording cannot produce a duplicate settlement under repeated refreshes
- [ ] every auto-recorded transaction is visibly marked and deletable
