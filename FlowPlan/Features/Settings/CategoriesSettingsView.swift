import Foundation
import SwiftData
import SwiftUI
import FlowPlanDomain

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProjectionStore.self) private var projectionStore

    @Query private var transactions: [TransactionEntity]
    @Query private var bills: [RecurringBillEntity]
    @Query private var debts: [DebtEntity]
    @Query private var budgets: [BudgetEntity]

    @AppStorage("incomeCategories") private var storedIncomeCategories = ""
    @AppStorage("expenseCategories") private var storedExpenseCategories = ""

    @State private var editingCategory: EditableCategory?
    @State private var categoryName = ""
    @State private var categoryKind = CategoryKind.expense
    @State private var categoryPendingDeletion: EditableCategory?
    @State private var presentedError: String?

    var body: some View {
        List {
            categorySection(title: "Income", kind: .income, categories: incomeCategories)
            categorySection(title: "Expenses", kind: .expense, categories: expenseCategories)
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCategory = EditableCategory(kind: .expense, originalName: nil)
                    categoryKind = .expense
                    categoryName = ""
                } label: {
                    Label("Add category", systemImage: "plus")
                }
            }
        }
        .alert(categoryEditorTitle, isPresented: categoryEditorPresented) {
            if editingCategory?.originalName == nil {
                Picker("Type", selection: $categoryKind) {
                    ForEach(CategoryKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }
            TextField("Category name", text: $categoryName)
            Button("Cancel", role: .cancel) {
                editingCategory = nil
            }
            Button("Save") {
                saveCategory()
            }
            .disabled(trimmedCategoryName.isEmpty)
        } message: {
            Text("Category names are used by transactions and monthly plans.")
        }
        .confirmationDialog(
            "Delete \(categoryPendingDeletion?.name ?? "category")?",
            isPresented: deletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Category", role: .destructive) {
                deletePendingCategory()
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            if let category = categoryPendingDeletion {
                let count = useCount(category)
                if count > 0 {
                    Text("\(count) record\(count == 1 ? "" : "s") use this category. They will be reassigned to \(category.kind.fallbackName).")
                } else {
                    Text("This removes the category from the available list.")
                }
            }
        }
        .alert("Unable to update categories", isPresented: errorPresented) {
            Button("OK", role: .cancel) {
                presentedError = nil
            }
        } message: {
            Text(presentedError ?? "The category change could not be saved.")
        }
    }

    private func categorySection(
        title: String,
        kind: CategoryKind,
        categories: [String]
    ) -> some View {
        Section(title) {
            ForEach(categories, id: \.self) { category in
                HStack {
                    Text(category)
                    Spacer()
                    let count = useCount(EditableCategory(kind: kind, originalName: category))
                    if count > 0 {
                        Text("\(count) in use")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if category != kind.fallbackName {
                        Button("Delete", role: .destructive) {
                            categoryPendingDeletion = EditableCategory(
                                kind: kind,
                                originalName: category
                            )
                        }
                    }

                    if category != kind.fallbackName {
                        Button("Rename") {
                            editingCategory = EditableCategory(kind: kind, originalName: category)
                            categoryKind = kind
                            categoryName = category
                        }
                        .tint(Palette.accent)
                    }
                }
            }
        }
    }

    private var incomeCategories: [String] {
        mergedCategories(kind: .income)
    }

    private var expenseCategories: [String] {
        mergedCategories(kind: .expense)
    }

    private func mergedCategories(kind: CategoryKind) -> [String] {
        let stored = persistedCategories(kind: kind)
        let used: [String]

        switch kind {
        case .income:
            used = transactions.filter { $0.type == .income }.map(\.category)
        case .expense:
            used = transactions.filter { $0.type == .expense }.map(\.category)
                + bills.map(\.category)
                + debts.map(\.category)
                + budgets.map(\.category)
        }

        return uniqueSorted(kind.defaults + stored + used)
    }

    private func saveCategory() {
        guard let editingCategory else {
            return
        }

        let newName = trimmedCategoryName
        guard !newName.isEmpty else {
            return
        }

        let kind = editingCategory.originalName == nil ? categoryKind : editingCategory.kind
        if let originalName = editingCategory.originalName, originalName != newName {
            guard renameRecords(from: originalName, to: newName, kind: kind) else {
                return
            }
            var names = persistedCategories(kind: kind)
            names.removeAll { $0.caseInsensitiveCompare(originalName) == .orderedSame }
            names.append(newName)
            store(names, for: kind)
        } else {
            var names = persistedCategories(kind: kind)
            names.append(newName)
            store(names, for: kind)
        }

        self.editingCategory = nil
    }

    private func renameRecords(from oldName: String, to newName: String, kind: CategoryKind) -> Bool {
        let timestamp = Date()

        switch kind {
        case .income:
            for transaction in transactions where transaction.type == .income && transaction.category == oldName {
                transaction.category = newName
                transaction.updatedAt = timestamp
            }
        case .expense:
            for transaction in transactions where transaction.type == .expense && transaction.category == oldName {
                transaction.category = newName
                transaction.updatedAt = timestamp
            }
            for bill in bills where bill.category == oldName {
                bill.category = newName
                bill.updatedAt = timestamp
            }
            for debt in debts where debt.category == oldName {
                debt.category = newName
                debt.updatedAt = timestamp
            }
            for budget in budgets where budget.category == oldName {
                budget.category = newName
                budget.updatedAt = timestamp
            }
        }

        return saveChanges()
    }

    private func deletePendingCategory() {
        guard let category = categoryPendingDeletion else {
            return
        }

        if useCount(category) > 0 {
            guard renameRecords(
                from: category.name,
                to: category.kind.fallbackName,
                kind: category.kind
            ) else {
                return
            }
        }
        var names = persistedCategories(kind: category.kind)
        names.removeAll { $0.caseInsensitiveCompare(category.name) == .orderedSame }
        store(names, for: category.kind)
        categoryPendingDeletion = nil
    }

    private func useCount(_ category: EditableCategory) -> Int {
        switch category.kind {
        case .income:
            return transactions.count { $0.type == .income && $0.category == category.name }
        case .expense:
            return transactions.count { $0.type == .expense && $0.category == category.name }
                + bills.count { $0.category == category.name }
                + debts.count { $0.category == category.name }
                + budgets.count { $0.category == category.name }
        }
    }

    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            projectionStore.refresh()
            return true
        } catch {
            modelContext.rollback()
            presentedError = "The category change could not be saved."
            return false
        }
    }

    private func persistedCategories(kind: CategoryKind) -> [String] {
        let value = kind == .income ? storedIncomeCategories : storedExpenseCategories
        return value.isEmpty ? kind.defaults : decodeCategories(value)
    }

    private func store(_ categories: [String], for kind: CategoryKind) {
        let value = encodeCategories(uniqueSorted(categories))
        if kind == .income {
            storedIncomeCategories = value
        } else {
            storedExpenseCategories = value
        }
    }

    private func decodeCategories(_ value: String) -> [String] {
        guard
            let data = value.data(using: .utf8),
            let categories = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return categories
    }

    private func encodeCategories(_ categories: [String]) -> String {
        guard
            let data = try? JSONEncoder().encode(categories),
            let value = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return value
    }

    private func uniqueSorted(_ categories: [String]) -> [String] {
        var seen = Set<String>()
        return categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var trimmedCategoryName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoryEditorTitle: String {
        editingCategory?.originalName == nil ? "Add Category" : "Rename Category"
    }

    private var categoryEditorPresented: Binding<Bool> {
        Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )
    }

    private var deletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { categoryPendingDeletion != nil },
            set: { if !$0 { categoryPendingDeletion = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}

private enum CategoryKind: String, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }
    var title: String { self == .income ? "Income" : "Expense" }
    var fallbackName: String { self == .income ? "Income" : "Other" }

    var defaults: [String] {
        switch self {
        case .income:
            return ["Income", "Salary", "Side Income"]
        case .expense:
            return [
                "Dining", "Entertainment", "Gas", "Groceries", "Housing",
                "Insurance", "Other", "Shopping", "Utilities"
            ]
        }
    }
}

private struct EditableCategory: Identifiable {
    let kind: CategoryKind
    let originalName: String?

    var id: String { "\(kind.rawValue)-\(originalName ?? "new")" }
    var name: String { originalName ?? "category" }
}
