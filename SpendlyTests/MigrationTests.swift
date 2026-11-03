import Foundation
import SwiftData
import Testing
@testable import Spendly

@MainActor
struct MigrationTests {
    @Test func v1StoreOpensWithEveryCategoryAsMain() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "v1-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let v1 = try ModelContainer(
                for: Schema(versionedSchema: SpendlySchemaV1.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = v1.mainContext
            let food = SpendlySchemaV1.ExpenseCategory(name: "Food & Dining", colorHex: "#FF6B6B", monthlyBudget: 400)
            context.insert(food)
            let lunch = SpendlySchemaV1.Expense(title: "Lunch", amount: Decimal(string: "12.50")!)
            context.insert(lunch)
            lunch.category = food
            context.insert(SpendlySchemaV1.Expense(title: "Loose change", amount: Decimal(string: "0.10")!))
            try context.save()
        }

        let v2 = try ModelContainer.spendly(url: url)
        let context = v2.mainContext
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let expenses = try context.fetch(FetchDescriptor<Expense>())

        #expect(categories.count == 1)
        let food = try #require(categories.first)
        #expect(food.name == "Food & Dining")
        #expect(food.colorHex == "#FF6B6B")
        #expect(food.monthlyBudget == 400)
        #expect(food.parent == nil)
        #expect(food.subcategories?.isEmpty ?? true)

        #expect(expenses.count == 2)
        #expect(expenses.reduce(0) { $0 + $1.amount } == Decimal(string: "12.60")!)
        #expect(expenses.first { $0.title == "Lunch" }?.category?.name == "Food & Dining")
        #expect(expenses.first { $0.title == "Loose change" }?.category == nil)
    }
}
