import Foundation
import SwiftData

enum SampleData {
    struct CategorySeed {
        let name: String
        let icon: String
        let color: String
        let budget: Double
        let samples: [(title: String, range: ClosedRange<Double>)]
    }

    static let defaultCategories: [CategorySeed] = [
        CategorySeed(name: "Food & Dining", icon: "fork.knife", color: "#FF6B6B", budget: 400,
                     samples: [("Lunch", 8...25), ("Dinner out", 25...80), ("Coffee", 3...7)]),
        CategorySeed(name: "Groceries", icon: "cart.fill", color: "#1DD1A1", budget: 500,
                     samples: [("Supermarket", 30...140), ("Farmers market", 10...40)]),
        CategorySeed(name: "Transport", icon: "car.fill", color: "#2E86DE", budget: 200,
                     samples: [("Fuel", 35...70), ("Taxi", 10...35), ("Metro card", 20...40)]),
        CategorySeed(name: "Shopping", icon: "bag.fill", color: "#A55EEA", budget: 0,
                     samples: [("Clothes", 25...120), ("Online order", 15...90)]),
        CategorySeed(name: "Bills & Utilities", icon: "bolt.fill", color: "#FECA57", budget: 300,
                     samples: [("Electricity", 50...110), ("Internet", 40...60), ("Phone plan", 25...45)]),
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
            ExpenseCategory(name: seed.name, iconName: seed.icon, colorHex: seed.color,
                            monthlyBudget: seed.budget, sortOrder: index)
        }
        for category in categories {
            context.insert(category)
        }
        try? context.save()
        return categories
    }

    /// Adds about 90 days of realistic expenses for trying the app out.
    static func insertSampleExpenses(in context: ModelContext, now: Date = .now) {
        var categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        if categories.isEmpty {
            categories = insertDefaultCategories(in: context)
        }
        let calendar = Calendar.current
        let methods = PaymentMethod.allCases
        let sampleTags = ["work", "family", "weekend", "essential", "treat"]

        for dayOffset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            for _ in 0..<Int.random(in: 0...3) {
                guard let category = categories.randomElement() else { continue }
                let seed = defaultCategories.first { $0.name == category.name }
                let sample: (title: String, range: ClosedRange<Double>) =
                    seed?.samples.randomElement() ?? (title: "Purchase", range: 5...60)
                let hour = Int.random(in: 8...21)
                let date = calendar.date(bySettingHour: hour, minute: Int.random(in: 0...59), second: 0, of: day) ?? day
                guard date <= now else { continue }

                let expense = Expense(
                    title: sample.title,
                    amount: (Double.random(in: sample.range) * 100).rounded() / 100,
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
