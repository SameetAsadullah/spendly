import Foundation
import SwiftData
import Testing
@testable import Spendly

@MainActor
struct ExpenseFilterSubcategoryTests {
    let container: ModelContainer
    let food: ExpenseCategory
    let outside: ExpenseCategory
    let coffee: ExpenseCategory
    var categories: [ExpenseCategory] { [food, outside, coffee] }

    init() throws {
        container = try ModelContainer.spendly(inMemory: true)
        let context = container.mainContext
        food = ExpenseCategory(name: "Food & Dining", iconName: "fork.knife", colorHex: "#FF6B6B")
        outside = ExpenseCategory(name: "Outside", iconName: "fork.knife", colorHex: "#000000")
        coffee = ExpenseCategory(name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#000000", sortOrder: 1)
        for category in [food, outside, coffee] {
            context.insert(category)
        }
        outside.parent = food
        coffee.parent = food
        try context.save()
    }

    private var foodID: PersistentIdentifier { food.persistentModelID }
    private var outsideID: PersistentIdentifier { outside.persistentModelID }
    private var coffeeID: PersistentIdentifier { coffee.persistentModelID }

    @Test func togglingEveryChipReturnsToAll() {
        var filter = ExpenseFilter()
        filter.toggle(food)
        filter.toggleSubcategory(outside, of: food)
        #expect(filter.subcategoryIDs[foodID] == [outsideID])
        filter.toggleSubcategory(coffee, of: food)
        filter.toggleSubcategory(nil, of: food)
        #expect(filter.subcategoryIDs[foodID] == nil)
        #expect(filter.categoryIDs == [foodID])
    }

    @Test func togglingTheLastChipOffReturnsToAll() {
        var filter = ExpenseFilter()
        filter.toggle(food)
        filter.toggleSubcategory(nil, of: food)
        #expect(filter.subcategoryIDs[foodID] == [foodID])
        filter.toggleSubcategory(nil, of: food)
        #expect(filter.subcategoryIDs[foodID] == nil)
    }

    @Test func deselectingTheMainCategoryDropsNarrowing() {
        var filter = ExpenseFilter()
        filter.toggle(food)
        filter.toggleSubcategory(coffee, of: food)
        filter.toggle(food)
        #expect(filter.categoryIDs.isEmpty)
        #expect(filter.subcategoryIDs.isEmpty)
    }

    @Test func chipsListEachChosenSubcategoryAndTheRemainder() {
        var filter = ExpenseFilter()
        filter.toggle(food)
        filter.toggleSubcategory(coffee, of: food)
        filter.toggleSubcategory(nil, of: food)
        let labels = filter.categoryChips(in: categories).map(\.label)
        #expect(labels == ["Food & Dining › Coffee", "Food & Dining › No subcategory"])
    }

    @Test func removingTheLastChipRemovesTheCategory() {
        var filter = ExpenseFilter()
        filter.toggle(food)
        filter.toggleSubcategory(coffee, of: food)
        filter.toggleSubcategory(outside, of: food)
        filter.remove(filter.categoryChips(in: categories)[0])
        #expect(filter.categoryIDs == [foodID])
        #expect(filter.subcategoryIDs[foodID]?.count == 1)
        filter.remove(filter.categoryChips(in: categories)[0])
        #expect(filter.categoryIDs.isEmpty)
        #expect(filter.subcategoryIDs.isEmpty)
    }

    @Test func directSubcategoryReadsAsPathAndRemoves() {
        var filter = ExpenseFilter.category(coffee)
        let chips = filter.categoryChips(in: categories)
        #expect(chips.map(\.label) == ["Food & Dining › Coffee"])
        filter.remove(chips[0])
        #expect(filter.categoryIDs.isEmpty)
    }

    @Test func singleCategoryIDIgnoresSeveralChoices() {
        var filter = ExpenseFilter.category(food)
        #expect(filter.singleCategoryID == foodID)
        filter.toggleSubcategory(coffee, of: food)
        #expect(filter.singleCategoryID == coffeeID)
        filter.toggleSubcategory(outside, of: food)
        #expect(filter.singleCategoryID == nil)
        #expect(ExpenseFilter.category(coffee).singleCategoryID == coffeeID)
    }

    @Test func foldingDirectSubcategoriesKeepsTheMatches() {
        let context = container.mainContext
        let latte = Expense(title: "Latte", amount: 4, date: .now)
        context.insert(latte)
        latte.category = coffee
        let lunch = Expense(title: "Lunch", amount: 20, date: .now)
        context.insert(lunch)
        lunch.category = outside

        var filter = ExpenseFilter.category(coffee)
        filter.foldDirectSubcategories(in: categories)
        #expect(filter.categoryIDs == [foodID])
        #expect(filter.subcategoryIDs[foodID] == [coffeeID])
        #expect(filter.apply(to: [latte, lunch]).map(\.title) == ["Latte"])
    }
}
