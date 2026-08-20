# FlowPlan — Decision Log

Records **why**, so agents do not relitigate settled architecture. Newest last.

---

## D-001 — The projection engine is a separate pure Swift package
**Decision.** `MonthlyProjectionEngine` and all financial domain types live in
`Packages/FlowPlanDomain`, a local SPM package importing `Foundation` only.

**Why.** The owner's hard constraint is that the engine carry zero SwiftUI and zero database
dependencies. A folder convention is enforced by opinion; a module boundary is enforced by the
compiler. It also buys a `swift test` loop that runs in seconds with no simulator, and it means
a future WidgetKit extension, Watch app, Shortcuts intent or What-If simulator reuses the exact
same engine instead of forking the financial logic.

**Consequence.** SwiftData `@Model` types can never leak into the domain. Repositories must map
entities to domain value types explicitly. That mapping is the price paid, and it is worth it.

---

## D-002 — SwiftData, not Core Data
**Decision.** Persistence is SwiftData.

**Why.** Master prompt §6 says use SwiftData if the deployment target supports it reliably. The
target is iOS 18 on Xcode 26.6 / Swift 6.3.3, comfortably past the iOS 17 floor. SwiftData
removes a large amount of boilerplate for a local-first app of this size.

**Consequence.** Entities are confined to `FlowPlan/Data/Persistence`. Because the domain is a
separate module (D-001), replacing the store later touches one folder.

---

## D-003 — iOS 18.0 deployment target
**Decision.** `IPHONEOS_DEPLOYMENT_TARGET = 18.0`.

**Why.** Greenfield project, so nothing to preserve. iOS 18 gives SwiftData, `@Observable`,
Swift Charts and modern `TabView`, while still covering iPhone XS and later — a far wider
install base than targeting iOS 26 would.

---

## D-004 — Hand-written `project.pbxproj` with file-system-synchronized groups
**Decision.** No XcodeGen, no Tuist. `project.pbxproj` is committed, uses `objectVersion = 77`
and `PBXFileSystemSynchronizedRootGroup` for `FlowPlan/` and `FlowPlanTests/`.

**Why.** Neither generator was installed, and adding one would put a build-time dependency
between an agent and a working build. Synchronized groups mean **any file added to those
folders is compiled automatically**, so implementation agents never edit the project file —
removing the most common merge conflict in multi-agent iOS work.

**Consequence.** New *targets* (a widget extension, say) still require editing the pbxproj by
hand, which is Agent 1's job.

---

## D-005 — Money is `Decimal`, stored as positive magnitudes
**Decision.** All money is `Decimal`. Amounts are stored positive; `TransactionType` carries
direction. Formatting flows through one `MoneyFormatter` using
`Decimal.formatted(.currency(code:))`.

**Why.** Binary floating point cannot represent 0.10 exactly and accumulates error over a month
of transactions — unacceptable in a product whose value proposition is a trusted number. Signed
amounts invite bugs where a "negative income" or "positive expense" silently inverts a total;
a magnitude plus an explicit type cannot. Centralised formatting keeps the app currency-agnostic
and avoids assuming two decimal places.

---

## D-006 — Reconciliation is by explicit link, settled in date order
**Decision.** A transaction may carry `settlesBillID` / `settlesIncomeID`. An expected
occurrence is retired only when a transaction links to it. Occurrences are settled in date
order, and one transaction settles at most one occurrence.

**Why.** Fuzzy matching on amount and date is the classic source of double counting: a
coincidental $120 expense should not silently retire the phone bill. An explicit link makes
reconciliation deterministic and testable. Date ordering makes the semi-monthly case correct —
two paychecks settle two of three expected occurrences and the third stays outstanding.

**Consequence.** The UI must offer "mark as paid" affordances that create the link. An unlinked
income transaction is treated as *extra* income: it raises the total and never reduces what is
still expected.

---

## D-007 — Actuals and expectations are counted in disjoint terms
**Decision.**
```
currentAvailableBalance    = startingBalance + incomeReceived − expensesPaid − savingsCompleted
projectedEndOfMonthBalance = currentAvailableBalance + remainingExpectedIncome
                           − remainingBills − remainingVariableSpending − remainingSavingsGoal
```

**Why.** This is the structural guarantee against double counting. Every actual event appears
in exactly one term; every outstanding obligation appears in exactly one other. Marking a bill
paid moves it across the boundary and leaves the projected balance unchanged — the single most
important invariant in the product, and a dedicated regression test.

---

## D-008 — The user supplies a starting balance, not a live balance
**Decision.** The user records `startingBalance` for the month; current available balance is
*derived* from it plus the month's actuals.

**Why.** Asking a user to keep a live "current balance" accurate by hand guarantees drift, and
drift in this field poisons the headline number. One value per month is checkable against a
bank statement and is self-consistent with the transactions already entered.

---

## D-009 — Budgets are allowances, not forecasts
**Decision.** A budgeted category contributes `max(0, limit − spent)` to remaining projected
spending; overspend contributes 0 remaining (it is already in actuals).

**Why.** If the full budget were always projected on top of actual spending, every purchase
would reduce the projection twice. Treating the budget as an allowance means spending inside
budget leaves the projection flat, overspending moves it by the overspend only, and spending in
an unbudgeted category moves it by the full amount — which is what a user intuitively expects.

---

## D-010 — Safe-to-Spend ignores the planned budget and rounds down
**Decision.** `spendableRemaining = currentAvailableBalance + remainingExpectedIncome
− remainingBills − remainingSavingsGoal`, divided by days remaining, rounded **down** to 2 dp.
`daysRemaining == 0` yields 0.

**Why.** Safe-to-spend answers "what can I actually spend today without breaking the month",
which depends on real uncommitted money, not on a plan. Rounding down means the app never
over-promises. The zero-days guard is an explicit division-by-zero defence with a test.

---

## D-011 — Swift 5 language mode in the app target, `Sendable` domain regardless
**Decision.** App target `SWIFT_VERSION = 5.0`. The domain package is fully `Sendable` and
value-typed.

**Why.** Swift 6 strict concurrency against SwiftData currently produces a large volume of
diagnostics that would consume iteration budget without improving the product. The domain — the
part where concurrency correctness actually matters — is `Sendable` today, so a later migration
is confined to the app layer. Revisit once the feature set is complete.

---

## D-012 — Agent 3 (QA) is a Codex review pass, not a fourth process
**Decision.** Agent 1 is Claude (architecture, integration, builds). Agent 2 is Codex
(implementation). Agent 3 is a **separate, review-only Codex invocation** with a read-and-report
scope.

**Why.** The master prompt caps the team at three agents and wants QA independent of the author.
Running QA as its own Codex job with a distinct spec gives an independent pass over the diff
without exceeding the cap or letting the implementer grade its own work.

---

## D-013 — Recurrence is computed, never materialised
**Decision.** `RecurrenceRule.occurrences(in:calendar:)` computes dates on demand. No future
occurrence rows are written to the store.

**Why.** Master prompt §22. Materialising a year of bills for every recurring item produces
thousands of rows that must then be migrated, deduplicated and reconciled when a rule changes.
Computing on demand keeps the store small and makes editing a rule instantaneous and correct
retroactively.

---

## D-014 — Debt and Accounts are deferred, not rejected
**Decision.** The design handoff treats **Debt** and **Accounts** as first-class concepts. Neither
is modelled for the MVP. Both are recorded here as deliberate post-MVP work.

**Why.** Debt is not a UI addition — it changes the projection engine. The handoff's own rule
("the mortgage payment sits in Monthly Bills, so only the payments outside bills enter the
projection") is a second reconciliation rule layered on top of the bill-settlement rule in D-006.
Two interacting no-double-counting rules in the highest-risk code in the product is not something
to add before the MVP's acceptance criteria are met and covered by tests.

Accounts are lower risk — an entity, a picker, a per-row subtitle and a settings screen, with no
engine change. They are deferred with Debt only to keep the remaining MVP scope stable, and can
be pulled forward cheaply if wanted.

**Consequence.** `TransactionSnapshot` already carries an `account` string, so per-transaction
account display is possible today without a schema change. A future `AccountEntity` would upgrade
that string to a relationship.

---

## D-015 — Design handoff assets stay out of the repository
**Decision.** `docs/design/` is git-ignored. The app icon is committed as a normal asset; the
screen captures are not.

**Why.** The captures contain the real owner name and employer, which were deliberately removed
from the tree and from every commit in history before publishing. PNG content cannot be
text-scrubbed the way the markdown was, so committing them would silently reverse that work.

**Consequence.** The handoff is available locally to whoever has it. Anything from it that the
implementation needs — palette, type treatment, component structure — is transcribed into specs
and this log rather than referenced by image.

---

## D-016 — Cross-cutting persistence and formatting issues are deferred as strategies
**Decision.** QA 1.5 and 1.6 will be addressed through one repository-wide transaction and
rollback strategy, not through isolated save-path patches. Decimal-to-floating-point conversion
remains permitted for chart and layout geometry; the savings slider's trapping
`Int(value.rounded())` path is clamped at the conversion boundary. QA 2.5, QA 2.8, and any
remaining minor presentation findings are deferred.

**Why.** Rollback and atomicity are consistency properties of the repository as a whole. Fixing
only the two observed paths would leave identical failure modes elsewhere and create a false
sense of safety. Chart APIs require floating-point geometry, so those conversions are legitimate
presentation boundaries; only the unguarded integer conversion could trap. The remaining insight
pace and compact-currency work needs an explicit product rule rather than an incidental copy or
formatter change.

**Consequence.** Follow-up work must introduce and test transaction semantics across every
repository mutation before closing QA 1.5 or 1.6. Chart geometry stays unchanged, the slider is
bounded safely, and the deferred QA findings remain listed in `PROJECT_STATUS.md`.
