#if DEBUG
import SwiftData
import SwiftUI

enum PreviewData {
    /// Default categories and fixed expenses over the last 3 months.
    @MainActor static let container = makeContainer()
    /// Default categories, no expenses.
    @MainActor static let emptyContainer = makeContainer(withExpenses: false)
    /// No categories and no expenses.
    @MainActor static let blankContainer = makeContainer(withExpenses: false, categories: false)

    @MainActor
    static func makeContainer(withExpenses: Bool = true, categories: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainer.spendly(inMemory: true)
            if categories {
                let mains = DefaultCategories.insert(in: container.mainContext)
                if withExpenses {
                    insertExpenses(into: mains, in: container.mainContext)
                }
            }
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }

    private static let expenses: [(category: String, title: String, amount: Decimal, daysAgo: Int,
                                   method: PaymentMethod, tags: [String])] = [
        ("Food & Dining › Coffee", "Coffee", 4.5, 0, .card, []),
        ("Transport › Public transport", "Metro card", 23.4, 1, .debit, ["work"]),
        ("Food & Dining › Outside", "Lunch", 16.9, 2, .card, ["work"]),
        ("Groceries", "Supermarket", 84.2, 3, .debit, ["essential"]),
        ("Entertainment", "Streaming", 14.06, 5, .card, []),
        ("Food & Dining", "Snacks", 6.3, 6, .cash, []),
        ("Bills & Utilities › Internet", "Internet", 44.78, 8, .bankTransfer, ["essential"]),
        ("Shopping", "Clothes", 46.2, 11, .card, ["treat"]),
        ("Transport › Fuel", "Fuel", 52.1, 13, .card, []),
        ("Food & Dining › Home", "Takeaway", 28.4, 16, .mobile, ["family"]),
        ("Travel", "Hotel", 195.39, 24, .card, ["weekend"]),
        ("Bills & Utilities › Electricity", "Electricity", 88.65, 34, .bankTransfer, ["essential"]),
        ("Food & Dining › Outside", "Dinner out", 62.0, 38, .card, ["weekend"]),
        ("Groceries", "Farmers market", 24.0, 41, .cash, []),
        ("Health", "Gym", 45.0, 47, .debit, []),
        ("Education", "Online course", 140.79, 55, .card, []),
        ("Transport › Rides", "Taxi", 21.5, 62, .mobile, []),
        ("Food & Dining › Coffee", "Coffee", 3.8, 68, .cash, []),
        ("", "Parking", 12.0, 75, .cash, []),
    ]

    @MainActor
    private static func insertExpenses(into mains: [ExpenseCategory], in context: ModelContext) {
        let byPath = Dictionary(uniqueKeysWithValues: mains.flatMap { [$0] + $0.sortedSubcategories }.map { ($0.path, $0) })
        for item in expenses {
            let date = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: .now) ?? .now
            let expense = Expense(title: item.title, amount: item.amount, date: date, paymentMethod: item.method, tags: item.tags)
            context.insert(expense)
            expense.category = byPath[item.category]
        }
        try? context.save()
    }

    /// Settings for one preview, kept apart from the app's own settings.
    /// Use with `.defaultAppStorage(_:)`. A budget of 0 means no budget.
    static func settings(monthlyBudget: Double = 0) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "SpendlyPreview.\(monthlyBudget)") ?? .standard
        defaults.set(monthlyBudget, forKey: AppSettings.monthlyBudgetKey)
        return defaults
    }
}

extension View {
    /// Light, dark and the `.accessibility3` text size, for `#Preview` variants.
    func previewVariant(_ variant: PreviewVariant) -> some View {
        self
            .preferredColorScheme(variant == .dark ? .dark : .light)
            .environment(\.dynamicTypeSize, variant == .accessibility ? .accessibility3 : .large)
    }
}

enum PreviewVariant {
    case light, dark, accessibility
}
#endif
