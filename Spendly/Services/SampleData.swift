import Foundation
import SwiftData

enum SampleData {
    typealias Sample = (title: String, range: ClosedRange<Double>)

    struct CategorySeed {
        let name: String
        let icon: String
        let color: String
        let budget: Decimal
        /// Expenses on the main category itself.
        let samples: [Sample]
        var subcategories: [SubcategorySeed] = []
    }

    struct SubcategorySeed {
        let name: String
        let icon: String
        var budget: Decimal = 0
        let samples: [Sample]
    }

    static let defaultCategories: [CategorySeed] = [
        CategorySeed(name: "Food & Dining", icon: "fork.knife", color: "#FF6B6B", budget: 400,
                     samples: [("Snacks", 3...10)],
                     subcategories: [
                        SubcategorySeed(name: "Home", icon: "house.fill", samples: [("Meal kit", 20...60), ("Takeaway", 15...40)]),
                        SubcategorySeed(name: "Outside", icon: "fork.knife", budget: 200,
                                        samples: [("Lunch", 8...25), ("Dinner out", 25...80)]),
                        SubcategorySeed(name: "Coffee", icon: "cup.and.saucer.fill", samples: [("Coffee", 3...7)]),
                     ]),
        CategorySeed(name: "Groceries", icon: "cart.fill", color: "#1DD1A1", budget: 500,
                     samples: [("Supermarket", 30...140), ("Farmers market", 10...40)]),
        CategorySeed(name: "Transport", icon: "car.fill", color: "#2E86DE", budget: 200,
                     samples: [("Parking", 5...20)],
                     subcategories: [
                        SubcategorySeed(name: "Fuel", icon: "fuelpump.fill", budget: 120, samples: [("Fuel", 35...70)]),
                        SubcategorySeed(name: "Rides", icon: "car.fill", samples: [("Taxi", 10...35)]),
                        SubcategorySeed(name: "Public transport", icon: "bus.fill", samples: [("Metro card", 20...40)]),
                     ]),
        CategorySeed(name: "Shopping", icon: "bag.fill", color: "#A55EEA", budget: 0,
                     samples: [("Clothes", 25...120), ("Online order", 15...90)]),
        CategorySeed(name: "Bills & Utilities", icon: "bolt.fill", color: "#FECA57", budget: 300,
                     samples: [("Service fee", 5...15)],
                     subcategories: [
                        SubcategorySeed(name: "Electricity", icon: "bolt.fill", samples: [("Electricity", 50...110)]),
                        SubcategorySeed(name: "Internet", icon: "wifi", samples: [("Internet", 40...60)]),
                        SubcategorySeed(name: "Phone", icon: "phone.fill", samples: [("Phone plan", 25...45)]),
                        SubcategorySeed(name: "Water", icon: "drop.fill", samples: [("Water", 20...45)]),
                     ]),
        CategorySeed(name: "Entertainment", icon: "film.fill", color: "#FF9F43", budget: 120,
                     samples: [("Movies", 12...30), ("Concert", 40...120), ("Streaming", 9...18)]),
        CategorySeed(name: "Health", icon: "cross.case.fill", color: "#FF6B9D", budget: 0,
                     samples: [("Pharmacy", 8...40), ("Gym", 30...60)]),
        CategorySeed(name: "Travel", icon: "airplane", color: "#48DBFB", budget: 0,
                     samples: [("Hotel", 90...250), ("Flight", 120...450)]),
        CategorySeed(name: "Education", icon: "book.fill", color: "#10AC84", budget: 0,
                     samples: [("Books", 10...45), ("Online course", 20...150)]),
        CategorySeed(name: "Other", icon: "ellipsis.circle.fill", color: "#8395A7", budget: 0,
                     samples: [("Miscellaneous", 5...50)]),
    ]

    static func seedDefaultCategoriesIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppSettings.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<ExpenseCategory>())) ?? 0
        if existing == 0 {
            insertDefaultCategories(in: context)
        }
        defaults.set(true, forKey: AppSettings.didSeedKey)
    }

    @discardableResult
    static func insertDefaultCategories(in context: ModelContext) -> [ExpenseCategory] {
        let categories = defaultCategories.enumerated().map { index, seed in
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

    /// Adds about 90 days of realistic expenses for trying the app out.
    static func insertSampleExpenses(in context: ModelContext, now: Date = .now) {
        var categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.parent == nil }))) ?? []
        if categories.isEmpty {
            categories = insertDefaultCategories(in: context)
        }
        // One group per main category, so subcategories don't make a category more frequent.
        let choices: [[(category: ExpenseCategory, samples: [Sample])]] = categories.map { category in
            let seed = defaultCategories.first { $0.name == category.name }
            let own = (category, seed?.samples ?? [(title: "Purchase", range: 5...60)])
            let subs = category.sortedSubcategories.compactMap { subcategory -> (ExpenseCategory, [Sample])? in
                guard let subSeed = seed?.subcategories.first(where: { $0.name == subcategory.name }) else { return nil }
                return (subcategory, subSeed.samples)
            }
            return [own] + subs
        }
        let calendar = Calendar.current
        let methods = PaymentMethod.allCases
        let sampleTags = ["work", "family", "weekend", "essential", "treat"]

        for dayOffset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            for _ in 0..<Int.random(in: 0...3) {
                guard let choice = choices.randomElement()?.randomElement(), let sample = choice.samples.randomElement() else { continue }
                let category = choice.category
                let hour = Int.random(in: 8...21)
                let date = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: day) ?? day
                guard date <= now else { continue }

                let expense = Expense(
                    title: sample.title,
                    amount: Decimal(Int((Double.random(in: sample.range) * 100).rounded())) / 100,
                    date: date,
                    paymentMethod: methods.randomElement() ?? .card,
                    tags: Bool.random() ? [sampleTags.randomElement()!] : []
                )
                context.insert(expense)
                expense.category = category
            }
        }
        try? context.save()
    }
}
