# Codex task spec — 12 — Accounts (Checking, Savings, Apple Card, Cash)

Pulls Accounts forward from the D-014 deferral. Update D-014 in `docs/DECISIONS.md` to record
that Accounts shipped and only Debt remains deferred.

The handoff design is `docs/design/handoff/screens/10-settings-accounts.png` (git-ignored, local
only). It is transcribed in full below — build from this text, not from the image.

## What an account is here
A **named label** with a transaction count. Not a balance-tracking ledger: no per-account
balance, no reconciliation, no transfers between accounts beyond the existing `.transfer`
transaction type. This is deliberately the small version — it must not touch the projection
engine, and `MonthlyProjection` must be unchanged.

## Scope
Anything under `FlowPlan/` and `FlowPlanTests/`, plus `docs/DECISIONS.md`.
Do NOT touch `Packages/FlowPlanDomain/**` or `FlowPlan.xcodeproj`.

## 1. Model
Add `AccountEntity` to `FlowPlan/Data/Persistence/Entities.swift`: `id: UUID`, `name: String`,
`createdAt: Date`, with `#Unique<AccountEntity>([\.id])`. Register it in
`PersistenceController.schema`.

`TransactionEntity.account` stays a `String` and remains the source of truth for what a
transaction is tagged with — do **not** migrate it to a relationship. `AccountEntity` is the
managed list of available names. That keeps existing data valid and avoids a migration.

Repository additions: `accounts() -> [Account]`, `addAccount(named:)`, `deleteAccount(_:)`,
`transactionCount(forAccount:)`. `Account` is a small app-layer value type (id, name); it does
not belong in the domain package.

On first launch after this ships, seed the account list from the distinct non-empty
`account` values already present on transactions, so nobody loses the labels they typed.

## 2. `AccountsSettingsView`
New screen, reached from a row in Settings. Match the handoff:

- Section header `ACCOUNTS` with `{n} accounts` on the trailing side.
- One row per account: a bordered **monogram square** (first two letters, uppercase, `accent` —
  the same component the bills and income rows use), the name, and a secondary subtitle:
  `{n} transactions`, or `No activity yet` when the count is zero.
- A trailing **delete** control per row.
- A final row with an inline `Add an account` text field and an `Add` button, disabled while the
  field is empty or duplicates an existing name (case-insensitively, trimmed).

**Deletion semantics — decide visibly, do not silently destroy data.** Deleting an account with
transactions must ask for confirmation naming the count ("Checking is used by 6 transactions"),
and on confirm it **clears the account label on those transactions** rather than deleting them.
Financial history must survive; only the label goes. Deleting an unused account needs no
confirmation. State this rule in a comment.

## 3. Use accounts where transactions are entered
`AddTransactionView` currently has a bare `TextField("Account", …)`. Replace it with a menu
picker over the managed accounts, plus a `New account…` option that creates one inline and
selects it. Keep the currently stored value selected when editing an existing transaction, even
if that name is no longer in the list (show it as the selection rather than losing it).

Show the account as part of the transaction row subtitle in Activity — `{Category} · {Account}`
when an account is set, matching the handoff — and add account to `TransactionFilter` so the
existing filter menu can filter by it.

## 4. Settings placement
Add an `Accounts` row to Settings. Put it directly above `Categories`, so the two list-management
screens sit together. Do not restructure the rest of Settings.

## Tests
- adding an account, then adding a duplicate name differing only by case, is rejected
- deleting an account used by transactions clears their label and **leaves every transaction and
  every projection figure unchanged** — assert `projectedEndOfMonthBalance` before and after
- deleting an unused account removes it
- the first-launch seed creates one account per distinct existing label and no duplicates
- filtering Activity by account returns the expected subset
- editing a transaction whose account no longer exists keeps its stored value

## Done when
- [ ] `cd Packages/FlowPlanDomain && swift test` unchanged (87 pass) — the domain must not move
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
- [ ] `grep -rn "TextField(\"Account\"" FlowPlan/` finds nothing
- [ ] D-014 updated: Accounts shipped, Debt still deferred
