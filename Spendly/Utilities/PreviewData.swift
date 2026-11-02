#if DEBUG
import SwiftData

enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer.spendly(inMemory: true)
            SampleData.insertSampleExpenses(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }()
}
#endif
