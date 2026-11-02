#if DEBUG
import SwiftData

enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: Expense.self, ExpenseCategory.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            SampleData.insertSampleExpenses(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }()
}
#endif
