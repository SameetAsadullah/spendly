import SwiftData
import SwiftUI

@main
struct SpendlyApp: App {
    @AppStorage(AppSettings.appearanceKey) private var appearance: Appearance = .system

    private let container: ModelContainer = {
        do {
            return try .spendly()
        } catch {
            fatalError("Could not open the expense store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .appLock()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
    }
}
