import SwiftData
import SwiftUI

struct SelectTabAction {
    fileprivate var handler: (RootView.AppTab) -> Void = { _ in }

    func callAsFunction(_ tab: RootView.AppTab) { handler(tab) }
}

private struct SelectTabKey: EnvironmentKey {
    static let defaultValue = SelectTabAction()
}

extension EnvironmentValues {
    /// Switches the root tab bar. Does nothing outside RootView, such as in previews.
    var selectTab: SelectTabAction {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}

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
                .tabItem { Label("Expenses", systemImage: "list.bullet") }
                .tag(AppTab.expenses)

            CategoryListView()
                .tabItem { Label("Categories", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.categories)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .environment(\.selectTab, SelectTabAction { selection = $0 })
        .task {
            DefaultCategories.seedIfNeeded(in: context)
            RecurringExpenseProcessor.process(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                RecurringExpenseProcessor.process(in: context)
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
#endif
