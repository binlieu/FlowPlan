import Foundation
import Testing
import FlowPlanDomain
@testable import FlowPlan

@Test
func creatingIncomeCategoryListsItOnlyUnderIncome() {
    let categories = CategoryCatalog.applyingChange(
        to: emptyCategoryLists,
        originalName: nil,
        originalKind: nil,
        newName: "Consulting",
        newKind: .income
    )

    #expect(categories[.income] == ["Consulting"])
    #expect(categories[.expense]?.contains("Consulting") == false)
    #expect(categories[.savings]?.contains("Consulting") == false)
}

@Test
func creatingSavingsCategoryListsItUnderSavings() {
    let categories = CategoryCatalog.applyingChange(
        to: emptyCategoryLists,
        originalName: nil,
        originalKind: nil,
        newName: "Emergency Fund",
        newKind: .savings
    )

    #expect(categories[.savings] == ["Emergency Fund"])
    #expect(categories[.income]?.contains("Emergency Fund") == false)
    #expect(categories[.expense]?.contains("Emergency Fund") == false)
}

@Test
func editingCategoryKindMovesItBetweenSections() {
    var startingCategories = emptyCategoryLists
    startingCategories[.expense] = ["Travel"]

    let categories = CategoryCatalog.applyingChange(
        to: startingCategories,
        originalName: "Travel",
        originalKind: .expense,
        newName: "Travel",
        newKind: .savings
    )

    #expect(categories[.expense]?.contains("Travel") == false)
    #expect(categories[.savings] == ["Travel"])
}

@Test
func duplicateCategoryNamesAreRejectedOnlyWithinTheSameKind() {
    let incomeCategories = ["  Side Work  "]
    let expenseCategories = ["Groceries"]

    #expect(CategoryCatalog.contains("side work", in: incomeCategories))
    #expect(CategoryCatalog.contains(" SIDE WORK ", in: incomeCategories))
    #expect(!CategoryCatalog.contains("Side Work", in: expenseCategories))
}

@Test
func transactionCategoryOptionsAreFilteredByTransactionType() {
    let transactions = [
        transaction(type: .income, category: "Paycheck"),
        transaction(type: .expense, category: "Groceries"),
        transaction(type: .savings, category: "Emergency Fund")
    ]

    let incomeOptions = AddTransactionView.categoryOptions(
        for: .income,
        transactions: transactions,
        budgetCategories: ["Dining"],
        billCategories: ["Utilities"],
        storedCategories: ["Consulting"],
        selectedCategory: nil
    )
    let expenseOptions = AddTransactionView.categoryOptions(
        for: .expense,
        transactions: transactions,
        budgetCategories: ["Dining"],
        billCategories: ["Utilities"],
        storedCategories: ["Shopping"],
        selectedCategory: nil
    )

    #expect(incomeOptions == ["Consulting", "Paycheck"])
    #expect(expenseOptions == ["Dining", "Groceries", "Shopping", "Utilities"])
}

@Test
func editingTransactionKeepsItsMismatchedSelectedCategory() {
    let options = AddTransactionView.categoryOptions(
        for: .income,
        transactions: [transaction(type: .expense, category: "Groceries")],
        budgetCategories: [],
        billCategories: [],
        storedCategories: ["Income"],
        selectedCategory: "Groceries"
    )

    #expect(options == ["Groceries", "Income"])
}

private let emptyCategoryLists: [CategoryKind: [String]] = [
    .income: [],
    .expense: [],
    .savings: []
]

private func transaction(
    type: TransactionType,
    category: String
) -> TransactionSnapshot {
    TransactionSnapshot(
        id: UUID(),
        date: Date(timeIntervalSince1970: 0),
        amount: 1,
        type: type,
        category: category,
        detail: category
    )
}
