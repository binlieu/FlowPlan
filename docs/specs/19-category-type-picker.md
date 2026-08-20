# Codex task spec — 19 — The category type picker never renders

## The defect, reported from a device
Adding a category offers no way to choose Income or Expense.

`CategoriesSettingsView` presents its editor with `.alert(categoryEditorTitle, isPresented:)` and
places a `Picker("Type", selection: $categoryKind)` inside it. **SwiftUI alerts render only
`TextField`s, `Button`s and the message — any other view, including a `Picker`, is silently
dropped.** The control exists in source and never appears on screen, so every new category takes
the default assigned when "Add category" is tapped: `.expense`.

Nothing is wrong with the code except that the framework ignores it, which is why it compiles
cleanly and no test caught it.

## Scope
- `FlowPlan/Features/Settings/CategoriesSettingsView.swift`
- `FlowPlan/Features/Transactions/AddTransactionView.swift`
- `FlowPlanTests/`

Do NOT touch `Packages/FlowPlanDomain/**` — 102 domain tests must pass unchanged.

## 1. Replace the alert with a sheet
Present the add/edit category editor as a **sheet containing a `Form`**, not an alert:

- a segmented `Picker` for the kind — Income / Expense / Savings, matching `CategoryKind`
- a `TextField` for the name
- Cancel and Save in the toolbar, Save disabled while the name is blank or duplicates an existing
  name of the same kind (case-insensitively, trimmed)
- when **editing** an existing category, keep the kind visible; changing it moves the category
  between sections, so state plainly what that means for records already using it

Audit the rest of the app for the same mistake: any `.alert` or `.confirmationDialog` containing
something other than `TextField`/`Button`/`Text` is a control the user cannot see. Fix any found
the same way and list them in your final message.

## 2. Filter the transaction category picker by type
`AddTransactionView` builds `existingCategories` from a union of transaction, bill and budget
categories with no regard for the transaction's type, so choosing **Income** still offers expense
categories like Groceries.

Filter the offered categories by the selected transaction type — income transactions offer income
categories, expenses offer expense categories, savings offer savings categories — keeping
"New category…", which must create the category with the matching kind. If the transaction being
edited already carries a category of another kind, keep it selected rather than silently dropping
it.

## Tests
- a category created as Income is listed under Income, not Expenses
- a category created as Savings is listed under Savings
- editing a category's kind moves it between sections
- a duplicate name within the same kind is rejected; the same name under a different kind is allowed
- the Add Transaction picker offers only income categories for an income transaction, and only
  expense categories for an expense
- editing a transaction whose category is of a different kind keeps that category selected

## Done when
- [ ] the type control is visible and usable when adding a category
- [ ] `grep -rn -A6 "\.alert(" FlowPlan/ | grep -c "Picker("` is 0
- [ ] `cd Packages/FlowPlanDomain && swift test` — 102 tests pass unchanged
- [ ] app builds for the iPhone 17 simulator, no new warnings, all app tests pass
