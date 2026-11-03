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
        guard filter.categoryIDs.count == 1, let id = filter.categoryIDs.first else { return nil }
        return categories.first { $0.persistentModelID == id }
    }

    private var availableTags: [String] {
        Array(Set(expenses.flatMap(\.tags))).sorted()
    }

    var body: some View {
        let results = filter.apply(to: expenses)
        let total = results.reduce(0) { $0 + $1.amount }

        List {
            if !results.isEmpty {
                Section {
                    summary(count: results.count, total: total)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            ForEach(sections(for: results)) { section in
                Section {
                    ForEach(section.items) { expense in
                        row(for: expense)
                    }
                } header: {
                    HStack {
                        Text(section.title)
                        Spacer()
                        Text(section.total.formattedCurrency(currency))
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .searchable(text: $filter.searchText, prompt: "Search title, notes, tags…")
        .safeAreaInset(edge: .top, spacing: 0) {
            if filter.isActive {
                ActiveFilterBar(filter: $filter, categories: categories, currency: currency)
            }
        }
        .overlay {
            if results.isEmpty {
                emptyState
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                filterButton
                moreMenu(results: results)
                Button {
                    editorRoute = .new
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                }
                .accessibilityLabel("Add expense")
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

    private func summary(count: Int, total: Decimal) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.isActive || !filter.searchText.isEmpty ? "Filtered total" : "Total spent")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Text(total.formattedCurrency(currency))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count) \(count == 1 ? "expense" : "expenses")")
                    .font(.subheadline.weight(.semibold))
                Text("avg \((total / Decimal(max(count, 1))).formattedCurrency(currency))")
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
        }
        .padding(16)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(for expense: Expense) -> some View {
        Button {
            editorRoute = .edit(expense)
        } label: {
            ExpenseRow(expense: expense, currency: currency, showsDay: filter.sort.grouping != .day)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(expense)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editorRoute = .duplicate(expense)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.indigo)
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
                .font(.title3)
                .overlay(alignment: .topTrailing) {
                    if filter.activeCount > 0 {
                        Text("\(filter.activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.red, in: Circle())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .accessibilityLabel("Filters")
        .accessibilityValue(filter.activeCount > 0 ? "\(filter.activeCount) active" : "None")
    }

    private func moreMenu(results: [Expense]) -> some View {
        Menu {
            Picker(selection: $filter.sort) {
                ForEach(SortOption.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)

            Section {
                ShareLink(
                    item: CSVDocument(expenses: results, currency: currency),
                    preview: SharePreview("\(results.count) expenses (CSV)")
                ) {
                    Label("Export Results as CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(results.isEmpty)
            }

            if filter.isActive {
                Button(role: .destructive) {
                    filter.clearFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .accessibilityLabel("Sort and export")
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
        } else if !filter.searchText.isEmpty && !filter.isActive {
            ContentUnavailableView.search(text: filter.searchText)
        } else {
            ContentUnavailableView {
                Label("No Matching Expenses", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Try changing or clearing your filters.")
            } actions: {
                Button("Clear Filters") {
                    filter.clearFilters()
                    filter.searchText = ""
                }
                .buttonStyle(.bordered)
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
                let name = expense.category?.name ?? "Uncategorized"
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
