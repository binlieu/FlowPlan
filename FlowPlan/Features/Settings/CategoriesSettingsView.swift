import Foundation
import SwiftData
import SwiftUI
import FlowPlanDomain

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ProjectionStore.self) private var projectionStore

    @Query private var transactions: [TransactionEntity]
    @Query private var bills: [RecurringBillEntity]
    @Query private var debts: [DebtEntity]
    @Query private var budgets: [BudgetEntity]

    @AppStorage("incomeCategories") private var storedIncomeCategories = ""
    @AppStorage("expenseCategories") private var storedExpenseCategories = ""
    @AppStorage("savingsCategories") private var storedSavingsCategories = ""

    @State private var editingCategory: EditableCategory?
    @State private var categoryName = ""
    @State private var categoryKind = CategoryKind.expense
    @State private var categoryPendingDeletion: EditableCategory?
    @State private var presentedError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "Categories")

                Group {
                    categorySection(title: "Income", kind: .income, categories: incomeCategories)
                    categorySection(title: "Expenses", kind: .expense, categories: expenseCategories)
                    categorySection(title: "Savings", kind: .savings, categories: savingsCategories)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
        .sheet(item: $editingCategory) { _ in
            categoryEditor
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeading(title: title)
            GroupedList(categories) { category in
                categoryRow(category, kind: kind)
            }
        }
    }

    private func categoryRow(_ category: String, kind: CategoryKind) -> some View {
        let editableCategory = EditableCategory(kind: kind, originalName: category)
        let count = useCount(editableCategory)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        categoryName(category)
                        Spacer(minLength: Spacing.sm)
                        categoryActions(for: editableCategory)
                    }
                    categoryUseCount(count)
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    categoryName(category)
                    Spacer(minLength: Spacing.sm)
                    categoryUseCount(count)
                    categoryActions(for: editableCategory)
                }
            }
        }
        .settingsRow()
    }

    private func categoryName(_ category: String) -> some View {
        Text(category)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func categoryUseCount(_ count: Int) -> some View {
        if count > 0 {
            Text("\(count) in use")
                .captionTypography()
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func categoryActions(for category: EditableCategory) -> some View {
        if category.name != category.kind.fallbackName {
            Menu {
                Button {
                    beginEditing(category)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    categoryPendingDeletion = category
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Actions for \(category.name)")
        }
    }

    private func beginEditing(_ category: EditableCategory) {
        editingCategory = category
        categoryKind = category.kind
        categoryName = category.name
    }

    private var incomeCategories: [String] {
        mergedCategories(kind: .income)
    }

    private var expenseCategories: [String] {
        mergedCategories(kind: .expense)
    }

    private var savingsCategories: [String] {
        mergedCategories(kind: .savings)
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
        case .savings:
            used = transactions.filter { $0.type == .savings }.map(\.category)
        }

        return CategoryCatalog.uniqueSorted(stored + used)
    }

    private func saveCategory() {
        guard let editingCategory else {
            return
        }

        let newName = trimmedCategoryName
        guard canSaveCategory else {
            return
        }

        let originalKind = editingCategory.kind
        if let originalName = editingCategory.originalName, originalName != newName {
            guard renameRecords(from: originalName, to: newName, kind: originalKind) else {
                return
            }
        }

        let categoriesByKind = Dictionary(
            uniqueKeysWithValues: CategoryKind.allCases.map {
                ($0, persistedCategories(kind: $0))
            }
        )
        let updatedCategories = CategoryCatalog.applyingChange(
            to: categoriesByKind,
            originalName: editingCategory.originalName,
            originalKind: editingCategory.originalName == nil ? nil : originalKind,
            newName: newName,
            newKind: categoryKind
        )

        if editingCategory.originalName != nil {
            store(updatedCategories[originalKind, default: []], for: originalKind)
        }
        store(updatedCategories[categoryKind, default: []], for: categoryKind)

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
        case .savings:
            for transaction in transactions where transaction.type == .savings && transaction.category == oldName {
                transaction.category = newName
                transaction.updatedAt = timestamp
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
        case .savings:
            return transactions.count { $0.type == .savings && $0.category == category.name }
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
        CategoryCatalog.categories(from: storedValue(for: kind), kind: kind)
    }

    private func store(_ categories: [String], for kind: CategoryKind) {
        let value = CategoryCatalog.encode(categories)
        switch kind {
        case .income:
            storedIncomeCategories = value
        case .expense:
            storedExpenseCategories = value
        case .savings:
            storedSavingsCategories = value
        }
    }

    private func storedValue(for kind: CategoryKind) -> String {
        switch kind {
        case .income:
            return storedIncomeCategories
        case .expense:
            return storedExpenseCategories
        case .savings:
            return storedSavingsCategories
        }
    }

    private var trimmedCategoryName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoryEditorTitle: String {
        editingCategory?.originalName == nil ? "Add Category" : "Edit Category"
    }

    private var canSaveCategory: Bool {
        guard !trimmedCategoryName.isEmpty else {
            return false
        }

        let excludedName = editingCategory?.kind == categoryKind
            ? editingCategory?.originalName
            : nil
        return !CategoryCatalog.contains(
            trimmedCategoryName,
            in: mergedCategories(kind: categoryKind),
            excluding: excludedName
        )
    }

    private var categoryEditor: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    ScreenHeader(title: categoryEditorTitle)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeading(title: "Category")
                        GroupedList(0..<2, rowContent: categoryEditorRow)

                        if editingCategory?.originalName != nil {
                            SettingsSectionFooter(
                                text: "Changing the type moves this category in the available list. "
                                    + "Existing records keep their current type; changing the name "
                                    + "updates those records."
                            )
                        } else {
                            SettingsSectionFooter(
                                text: "Category names are used by transactions and monthly plans."
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.bottom, Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingCategory = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(!canSaveCategory)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func categoryEditorRow(_ row: Int) -> some View {
        switch row {
        case 0:
            Picker("Type", selection: $categoryKind) {
                ForEach(CategoryKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .settingsRow()
        case 1:
            TextField("Category name", text: $categoryName)
                .textInputAutocapitalization(.words)
                .settingsRow()
        default:
            EmptyView()
        }
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

enum CategoryKind: String, CaseIterable, Identifiable {
    case income
    case expense
    case savings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .savings: "Savings"
        }
    }

    var fallbackName: String {
        switch self {
        case .income: "Income"
        case .expense: "Other"
        case .savings: "Savings"
        }
    }

    init?(transactionType: TransactionType) {
        switch transactionType {
        case .income:
            self = .income
        case .expense:
            self = .expense
        case .savings:
            self = .savings
        case .transfer:
            return nil
        }
    }

    var defaults: [String] {
        switch self {
        case .income:
            return ["Income", "Salary", "Side Income"]
        case .expense:
            return [
                "Dining", "Entertainment", "Gas", "Groceries", "Housing",
                "Insurance", "Other", "Shopping", "Utilities"
            ]
        case .savings:
            return ["Savings"]
        }
    }
}

private struct EditableCategory: Identifiable {
    let kind: CategoryKind
    let originalName: String?

    var id: String { "\(kind.rawValue)-\(originalName ?? "new")" }
    var name: String { originalName ?? "category" }
}

enum CategoryCatalog {
    static func categories(from storedValue: String, kind: CategoryKind) -> [String] {
        guard !storedValue.isEmpty else {
            return kind.defaults
        }
        guard
            let data = storedValue.data(using: .utf8),
            let categories = try? JSONDecoder().decode([String].self, from: data)
        else {
            return kind.defaults
        }
        return uniqueSorted(categories)
    }

    static func encode(_ categories: [String]) -> String {
        guard
            let data = try? JSONEncoder().encode(uniqueSorted(categories)),
            let value = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return value
    }

    static func uniqueSorted(_ categories: [String]) -> [String] {
        var seen = Set<String>()
        return categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert(identity(for: $0)).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func contains(
        _ name: String,
        in categories: [String],
        excluding excludedName: String? = nil
    ) -> Bool {
        let identity = identity(for: name)
        let excludedIdentity = excludedName.map { self.identity(for: $0) }
        return categories.contains {
            let candidateIdentity = self.identity(for: $0)
            return candidateIdentity == identity && candidateIdentity != excludedIdentity
        }
    }

    static func applyingChange(
        to categoriesByKind: [CategoryKind: [String]],
        originalName: String?,
        originalKind: CategoryKind?,
        newName: String,
        newKind: CategoryKind
    ) -> [CategoryKind: [String]] {
        var updated = categoriesByKind

        if let originalName, let originalKind {
            updated[originalKind, default: []].removeAll {
                identity(for: $0) == identity(for: originalName)
            }
        }

        updated[newKind, default: []].append(newName)
        for kind in CategoryKind.allCases {
            updated[kind] = uniqueSorted(updated[kind, default: []])
        }
        return updated
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        identity(for: lhs) == identity(for: rhs)
    }

    private static func identity(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

#if DEBUG
#Preview("Categories — Light") {
    FlowPlanPreviewHost(colorScheme: .light) {
        NavigationStack {
            CategoriesSettingsView()
        }
    }
}

#Preview("Categories — Dark") {
    FlowPlanPreviewHost(colorScheme: .dark) {
        NavigationStack {
            CategoriesSettingsView()
        }
    }
}
#endif
