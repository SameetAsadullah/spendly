import Foundation
import SwiftData
import Testing
@testable import Spendly

@MainActor
struct SubcategoryTests {
    let container: ModelContainer
    let context: ModelContext
    let food: ExpenseCategory
    let outside: ExpenseCategory
    let coffee: ExpenseCategory

    init() throws {
        container = try ModelContainer.spendly(inMemory: true)
        context = container.mainContext
        food = ExpenseCategory(name: "Food & Dining", iconName: "fork.knife", colorHex: "#FF6B6B", monthlyBudget: 400)
        outside = ExpenseCategory(name: "Outside", iconName: "fork.knife", colorHex: "#000000", monthlyBudget: 200)
        coffee = ExpenseCategory(name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#000000", sortOrder: 1)
        for category in [food, outside, coffee] {
            context.insert(category)
        }
        outside.parent = food
        coffee.parent = food
        add("Snacks", 5, to: food)
        add("Lunch", 20, to: outside)
        add("Dinner", 30, to: outside)
        add("Latte", 4, to: coffee)
        try context.save()
    }

    @discardableResult
    private func add(_ title: String, _ amount: Decimal, to category: ExpenseCategory?, date: Date = .now) -> Expense {
        let expense = Expense(title: title, amount: amount, date: date)
        context.insert(expense)
        expense.category = category
        return expense
    }

    private func expenses() throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>())
    }

    @Test func subcategoryUsesParentColourAndPath() {
        #expect(outside.color == food.color)
        #expect(outside.mainCategory === food)
        #expect(food.mainCategory === food)
        #expect(outside.path == "Food & Dining › Outside")
        #expect(food.path == "Food & Dining")
        #expect(food.sortedSubcategories.map(\.name) == ["Outside", "Coffee"])
    }

    @Test func mainTotalsIncludeSubcategories() throws {
        let month = Calendar.current.monthInterval(for: .now)
        #expect(food.total(in: month) == 59)
        #expect(outside.total(in: month) == 50)
        #expect(food.totalExpenseCount == 4)

        let summary = MonthSummary(allExpenses: try expenses(), month: .now)
        #expect(summary.slices.count == 1)
        #expect(summary.spent(in: food) == 59)
        #expect(summary.spent(in: outside) == 50)
        #expect(summary.spent(in: coffee) == 4)

        let subslices = try #require(summary.slices.first?.subslices)
        #expect(subslices.map(\.name) == ["Outside", "Coffee", "No subcategory"])
        #expect(subslices.last?.total == 5)
    }

    @Test func filterOnMainCategoryIncludesSubcategories() throws {
        let all = try expenses()
        #expect(ExpenseFilter.category(food).apply(to: all).count == 4)
        #expect(ExpenseFilter.category(outside).apply(to: all).map(\.title).sorted() == ["Dinner", "Lunch"])

        var narrowed = ExpenseFilter.category(food)
        narrowed.subcategoryIDs[food.persistentModelID] = [coffee.persistentModelID, food.persistentModelID]
        #expect(narrowed.apply(to: all).map(\.title).sorted() == ["Latte", "Snacks"])
    }

    @Test func deletingSubcategoryMovesExpensesToParent() throws {
        outside.delete(includingExpenses: true, in: context)
        try context.save()

        let all = try expenses()
        #expect(all.count == 4)
        #expect(all.filter { $0.category === food }.map(\.title).sorted() == ["Dinner", "Lunch", "Snacks"])
        #expect(food.sortedSubcategories.map(\.name) == ["Coffee"])
    }

    @Test func deletingMainCategoryOnlyLeavesExpensesUncategorized() throws {
        food.delete(includingExpenses: false, in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0)
        let all = try expenses()
        #expect(all.count == 4)
        #expect(all.allSatisfy { $0.category == nil })
    }

    @Test func deletingMainCategoryWithExpensesRemovesEverything() throws {
        add("Bus", 3, to: nil)
        food.delete(includingExpenses: true, in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0)
        #expect(try expenses().map(\.title) == ["Bus"])
    }

    @Test func stackedTotalsHaveOneEntryPerMonthAndSeries() throws {
        let series = MonthlyTrend.series(for: food)
        #expect(series.map(\.name) == ["Outside", "Coffee", "No subcategory"])

        let totals = MonthlyTrend.subcategoryTotals(for: try expenses(), of: food, monthsEndingAt: .now, count: 6)
        #expect(totals.count == 18)
        let thisMonth = Calendar.current.startOfMonth(for: .now)
        let current = totals.filter { $0.month == thisMonth }
        #expect(current.map(\.total) == [50, 4, 5])
        #expect(totals.filter { $0.month != thisMonth }.allSatisfy { $0.total == 0 })
    }

    @Test func shadesFollowTheSpec() {
        #expect(ExpenseCategory.shadeOpacity(index: 0, count: 3) == 1)
        #expect(ExpenseCategory.shadeOpacity(index: 1, count: 3) == 0.6)
        #expect(ExpenseCategory.shadeOpacity(index: 2, count: 3) == 0.35)
        #expect(abs(ExpenseCategory.shadeOpacity(index: 3, count: 4) - 0.35) < 0.0001)
    }

    @Test func defaultCategoriesIncludeSubcategories() throws {
        let sample = try ModelContainer.spendly(inMemory: true)
        DefaultCategories.insert(in: sample.mainContext)
        let mains = try sample.mainContext.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.parent == nil }))
        let byName = Dictionary(uniqueKeysWithValues: mains.map { ($0.name, $0.sortedSubcategories.map(\.name)) })
        #expect(mains.count == 10)
        #expect(byName["Food & Dining"] == ["Home", "Outside", "Coffee"])
        #expect(byName["Transport"] == ["Fuel", "Rides", "Public transport"])
        #expect(byName["Bills & Utilities"] == ["Electricity", "Internet", "Phone", "Water"])
    }
}
