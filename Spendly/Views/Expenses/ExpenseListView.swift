import SwiftData
import SwiftUI

struct ExpensesTab: View {
    var body: some View {
        NavigationStack {
            ExpenseListView()
        }
    }
}

struct ExpenseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    let title: String
    @State private var filter: ExpenseFilter
    @State private var showFilters = false
    @State private var editorRoute: ExpenseEditorRoute?
    @State private var pendingDelete: Expense?

    init(title: String = "Expenses", filter: ExpenseFilter = ExpenseFilter()) {
        self.title = title
        _filter = State(initialValue: filter)
    }

    private struct ExpenseSection: Identifiable {
        let id: String
        let title: String
        let items: [Expense]
        var total: Decimal { items.reduce(0) { $0 + $1.amount } }
    }

    private var presetCategory: ExpenseCategory? {
        guard filter.categoryIDs.count == 1,
              let id = filter.singleCategoryID ?? filter.categoryIDs.first
        else { return nil }
        return categories.first { $0.persistentModelID == id }
    }

    private var budgetCategory: ExpenseCategory? {
        guard !filter.includeUncategorized,
              let id = filter.singleCategoryID,
              let category = categories.first(where: { $0.persistentModelID == id }),
              category.hasBudget
        else { return nil }
        return category
    }

    private var availableTags: [String] {
        Array(Set(expenses.flatMap(\.tags))).sorted()
    }

    var body: some View {
        let results = filter.apply(to: expenses)
        let total = results.reduce(0) { $0 + $1.amount }

        Group {
            if results.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        summary(count: results.count, total: total)
                        if let budgetCategory {
                            budgetCard(for: budgetCategory)
                        }
                        if filter.isActive {
                            ActiveFilterBar(filter: $filter, categories: categories, currency: currency)
                                .padding(.horizontal, Theme.Spacing.gutter)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)

                    ForEach(sections(for: results)) { section in
                        Section {
                            ForEach(section.items) { expense in
                                row(for: expense)
                            }
                        } header: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(section.title)
                                Spacer()
                                Text(section.total.formattedCurrency(currency))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(title)
        .searchable(text: $filter.searchText, prompt: "Search title, notes or tags")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterButton
                moreMenu(results: results)
                Button {
                    editorRoute = .new
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Expense")
            }
        }
        .sheet(isPresented: $showFilters) {
            ExpenseFilterSheet(filter: $filter, categories: categories, availableTags: availableTags)
        }
        .sheet(item: $editorRoute) { route in
            ExpenseEditorView(route: route, presetCategory: presetCategory)
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { expense in
            Button("Delete \(expense.displayTitle)", role: .destructive) { delete(expense) }
        }
    }

    // MARK: Pieces

    private func summaryText(count: Int) -> String {
        let noun = count == 1 ? "expense" : "expenses"
        let hasSearch = !filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !filter.isActive && !hasSearch {
            return "\(count) \(noun) · all time"
        }
        if !hasSearch, filter.activeCount == 1, filter.datePreset != .allTime, filter.datePreset != .custom {
            return "\(count) \(noun) · \(filter.datePreset.title.lowercased())"
        }
        return "\(count) matching \(noun)"
    }

    private func summary(count: Int, total: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summaryText(count: count))
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    totalText(total)
                    Spacer(minLength: 8)
                    sortText
                }
                VStack(alignment: .leading, spacing: 2) {
                    totalText(total)
                    sortText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.gutter)
        .accessibilityElement(children: .combine)
    }

    private func totalText(_ total: Decimal) -> some View {
        Text(total.formattedCurrency(currency))
            .font(.listTotalAmount)
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private func budgetCard(for category: ExpenseCategory) -> some View {
        let spent = category.total(in: Calendar.current.monthInterval(for: .now))
        let budget = category.monthlyBudget
        let remaining = budget - spent
        let progress = (spent / budget).doubleValue
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(category.path) this month")
                .font(.caption)
                .foregroundStyle(.secondary)
            BudgetBar(progress: progress, tint: category.color)
            HStack(alignment: .firstTextBaseline) {
                if remaining < 0 {
                    Text("\((-remaining).formattedCurrency(currency)) over")
                        .foregroundStyle(.red)
                } else {
                    Text("\(remaining.formattedCurrency(currency)) left")
                }
                Spacer(minLength: 8)
                Text("\(spent.formattedCurrency(currency)) of \(budget.formattedCurrency(currency, fractionDigits: 0))")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
        }
        .padding(Theme.Spacing.gutter)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.Spacing.gutter)
        .accessibilityElement(children: .combine)
    }

    private var sortText: some View {
        Text(filter.sort.title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func row(for expense: Expense) -> some View {
        Button {
            editorRoute = .edit(expense)
        } label: {
            ExpenseRow(expense: expense, currency: currency, showsDay: filter.sort.grouping != .day)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // The first action sits at the screen edge, so the order reads Edit, Duplicate, Delete.
            Button(role: .destructive) {
                delete(expense)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editorRoute = .duplicate(expense)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.gray)
            Button {
                editorRoute = .edit(expense)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Theme.brandFill)
        }
        .contextMenu {
            Button { editorRoute = .edit(expense) } label: { Label("Edit", systemImage: "pencil") }
            Button { editorRoute = .duplicate(expense) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive) { pendingDelete = expense } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            Image(systemName: filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter and Sort")
        .accessibilityValue(filter.isActive ? "\(filter.activeCount) active" : "")
    }

    private func moreMenu(results: [Expense]) -> some View {
        Menu {
            Picker("Sort By", selection: $filter.sort) {
                ForEach(SortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.inline)

            Section {
                ShareLink(
                    item: CSVDocument(expenses: results, currency: currency),
                    preview: SharePreview("\(results.count) \(results.count == 1 ? "expense" : "expenses") (CSV)")
                ) {
                    Label(
                        "Export \(results.count) \(results.count == 1 ? "Result" : "Results") as CSV",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .disabled(results.isEmpty)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private var emptyState: some View {
        if expenses.isEmpty {
            ContentUnavailableView {
                Label("No Expenses Yet", systemImage: "tray")
            } description: {
                Text("Add your first expense to start tracking where your money goes.")
            } actions: {
                Button("Add Expense") { editorRoute = .new }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 0) {
                if filter.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No expenses match your filters.")
                    )
                } else {
                    ContentUnavailableView.search(text: filter.searchText)
                }
                if filter.isActive {
                    Button("Clear Filters") {
                        filter.clearFilters()
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: Logic

    private func sections(for items: [Expense]) -> [ExpenseSection] {
        switch filter.sort.grouping {
        case .day:
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
            let ascending = filter.sort == .oldest
            let days = grouped.keys.sorted { ascending ? $0 < $1 : $0 > $1 }
            return days.map { day in
                ExpenseSection(id: day.ISO8601Format(), title: DayTitle.string(for: day), items: grouped[day] ?? [])
            }
        case .category:
            var order: [String] = []
            var grouped: [String: [Expense]] = [:]
            for expense in items {
                let name = expense.category?.path ?? "Uncategorized"
                if grouped[name] == nil { order.append(name) }
                grouped[name, default: []].append(expense)
            }
            return order.map { ExpenseSection(id: $0, title: $0, items: grouped[$0] ?? []) }
        case .flat:
            guard !items.isEmpty else { return [] }
            return [ExpenseSection(id: "all", title: filter.sort.title, items: items)]
        }
    }

    private func delete(_ expense: Expense) {
        withAnimation {
            context.delete(expense)
            try? context.save()
        }
    }
}

#if DEBUG
private var previewFiltered: ExpenseFilter {
    var filter = ExpenseFilter()
    filter.datePreset = .thisMonth
    filter.paymentMethods = [.card]
    return filter
}

private var previewNoResults: ExpenseFilter {
    var filter = previewFiltered
    filter.searchText = "zzzzqx"
    return filter
}

@MainActor private func previewSubcategoryFilter() -> ExpenseFilter {
    let context = ModelContext(PreviewData.container)
    let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
    return .category(categories.first { $0.name == "Outside" })
}

#Preview("Expenses light") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Expenses dark") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Expenses accessibility3") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}

#Preview("Filtered light") {
    NavigationStack { ExpenseListView(filter: previewFiltered) }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Filtered dark") {
    NavigationStack { ExpenseListView(filter: previewFiltered) }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Filtered accessibility3") {
    NavigationStack { ExpenseListView(filter: previewFiltered) }
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}

#Preview("No results light") {
    NavigationStack { ExpenseListView(filter: previewNoResults) }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("No results dark") {
    NavigationStack { ExpenseListView(filter: previewNoResults) }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("No results accessibility3") {
    NavigationStack { ExpenseListView(filter: previewNoResults) }
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}

#Preview("No expenses light") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.emptyContainer)
        .previewVariant(.light)
}

#Preview("No expenses dark") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.emptyContainer)
        .previewVariant(.dark)
}

#Preview("No expenses accessibility3") {
    NavigationStack { ExpenseListView() }
        .modelContainer(PreviewData.emptyContainer)
        .previewVariant(.accessibility)
}

#Preview("Subcategory light") {
    NavigationStack { ExpenseListView(filter: previewSubcategoryFilter()) }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Subcategory dark") {
    NavigationStack { ExpenseListView(filter: previewSubcategoryFilter()) }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}
#endif
