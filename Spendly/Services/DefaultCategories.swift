import Foundation
import SwiftData

/// The suggested categories the app adds on first launch.
enum DefaultCategories {
    struct Seed {
        let name: String
        let icon: String
        let color: String
        let budget: Decimal
        var subcategories: [SubcategorySeed] = []
    }

    struct SubcategorySeed {
        let name: String
        let icon: String
        var budget: Decimal = 0
    }

    static let seeds: [Seed] = [
        Seed(name: "Food & Dining", icon: "fork.knife", color: "#FF6B6B", budget: 400, subcategories: [
            SubcategorySeed(name: "Home", icon: "house.fill"),
            SubcategorySeed(name: "Outside", icon: "fork.knife", budget: 200),
            SubcategorySeed(name: "Coffee", icon: "cup.and.saucer.fill"),
        ]),
        Seed(name: "Groceries", icon: "cart.fill", color: "#1DD1A1", budget: 500),
        Seed(name: "Transport", icon: "car.fill", color: "#2E86DE", budget: 200, subcategories: [
            SubcategorySeed(name: "Fuel", icon: "fuelpump.fill", budget: 120),
            SubcategorySeed(name: "Rides", icon: "car.fill"),
            SubcategorySeed(name: "Public transport", icon: "bus.fill"),
        ]),
        Seed(name: "Shopping", icon: "bag.fill", color: "#A55EEA", budget: 0),
        Seed(name: "Bills & Utilities", icon: "bolt.fill", color: "#FECA57", budget: 300, subcategories: [
            SubcategorySeed(name: "Electricity", icon: "bolt.fill"),
            SubcategorySeed(name: "Internet", icon: "wifi"),
            SubcategorySeed(name: "Phone", icon: "phone.fill"),
            SubcategorySeed(name: "Water", icon: "drop.fill"),
        ]),
        Seed(name: "Entertainment", icon: "film.fill", color: "#FF9F43", budget: 120),
        Seed(name: "Health", icon: "cross.case.fill", color: "#FF6B9D", budget: 0),
        Seed(name: "Travel", icon: "airplane", color: "#48DBFB", budget: 0),
        Seed(name: "Education", icon: "book.fill", color: "#10AC84", budget: 0),
        Seed(name: "Other", icon: "ellipsis.circle.fill", color: "#8395A7", budget: 0),
    ]

    static func seedIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppSettings.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<ExpenseCategory>())) ?? 0
        if existing == 0 {
            insert(in: context)
        }
        defaults.set(true, forKey: AppSettings.didSeedKey)
    }

    @discardableResult
    static func insert(in context: ModelContext) -> [ExpenseCategory] {
        let categories = seeds.enumerated().map { index, seed in
            let category = ExpenseCategory(name: seed.name, iconName: seed.icon, colorHex: seed.color,
                                           monthlyBudget: seed.budget, sortOrder: index)
            context.insert(category)
            for (subIndex, subSeed) in seed.subcategories.enumerated() {
                let subcategory = ExpenseCategory(name: subSeed.name, iconName: subSeed.icon, colorHex: seed.color,
                                                  monthlyBudget: subSeed.budget, sortOrder: subIndex)
                context.insert(subcategory)
                subcategory.parent = category
            }
            return category
        }
        try? context.save()
        return categories
    }
}
