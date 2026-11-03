#if DEBUG
import SwiftData
import SwiftUI

enum PreviewData {
    /// Default categories and about 90 days of sample expenses.
    @MainActor static let container = makeContainer()
    /// Default categories, no expenses.
    @MainActor static let emptyContainer = makeContainer(sampleExpenses: false)
    /// No categories and no expenses.
    @MainActor static let blankContainer = makeContainer(sampleExpenses: false, categories: false)

    @MainActor
    static func makeContainer(sampleExpenses: Bool = true, categories: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainer.spendly(inMemory: true)
            if sampleExpenses {
                SampleData.insertSampleExpenses(in: container.mainContext)
            } else if categories {
                SampleData.insertDefaultCategories(in: container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
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
