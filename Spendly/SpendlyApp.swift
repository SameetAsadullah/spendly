import SwiftData
import SwiftUI

@main
struct SpendlyApp: App {
    @AppStorage(AppSettings.appearanceKey) private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [Expense.self, ExpenseCategory.self])
    }
}
