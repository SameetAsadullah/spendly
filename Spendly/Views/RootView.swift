import SwiftData
import SwiftUI

struct RootView: View {
    enum AppTab: Hashable {
        case overview, expenses, categories, settings
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .overview

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }
                .tag(AppTab.overview)

            ExpensesTab()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle.portrait.fill") }
                .tag(AppTab.expenses)

            CategoryListView()
                .tabItem { Label("Categories", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.categories)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .task {
            SampleData.seedDefaultCategoriesIfNeeded(in: context)
            RecurringExpenseProcessor.process(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                RecurringExpenseProcessor.process(in: context)
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
