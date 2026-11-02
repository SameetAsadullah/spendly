import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @Query private var expenses: [Expense]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    @State private var showNewCategory = false
    @State private var editingCategory: ExpenseCategory?
    @State private var pendingDelete: ExpenseCategory?

    private var monthSpending: [PersistentIdentifier: Decimal] {
        let month = Calendar.current.monthInterval(for: .now)
        var totals: [PersistentIdentifier: Decimal] = [:]
        for expense in expenses where month.containsHalfOpen(expense.date) {
            if let id = expense.category?.persistentModelID {
                totals[id, default: 0] += expense.amount
            }
        }
        return totals
    }

    var body: some View {
        let spending = monthSpending

        NavigationStack {
            List {
                if !categories.isEmpty {
                    Section {
                        overview(spending: spending)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    ForEach(categories) { category in
                        NavigationLink {
                            ExpenseListView(title: category.name, filter: .category(category))
                        } label: {
                            CategoryRow(
                                category: category,
                                spent: spending[category.persistentModelID] ?? 0,
                                currency: currency
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDelete = category
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingCategory = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                        .contextMenu {
                            Button { editingCategory = category } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { pendingDelete = category } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onMove(perform: move)
                } header: {
                    if !categories.isEmpty { Text("This month") }
                } footer: {
                    if !categories.isEmpty {
                        Text("Swipe to edit or delete. Tap Edit to reorder.")
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !categories.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title3)
                    }
                    .accessibilityLabel("Add category")
                }
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No Categories", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Create categories like Food, Rent or Travel to organize your expenses.")
                    } actions: {
                        Button("Add Category") { showNewCategory = true }
                            .buttonStyle(.borderedProminent)
                        Button("Add Suggested Categories") {
                            SampleData.insertDefaultCategories(in: context)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryEditorView(category: nil)
            }
            .sheet(item: $editingCategory) { category in
                CategoryEditorView(category: category)
            }
            .confirmationDialog(
                "Delete \(pendingDelete?.name ?? "category")?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { category in
                Button("Delete Category Only", role: .destructive) {
                    delete(category, includingExpenses: false)
                }
                if category.expenseCount > 0 {
                    Button("Delete Category and \(category.expenseCount) Expenses", role: .destructive) {
                        delete(category, includingExpenses: true)
                    }
                }
            } message: { category in
                if category.expenseCount > 0 {
                    Text("\(category.expenseCount) expenses use this category. If you keep them, they become Uncategorized.")
                } else {
                    Text("This category has no expenses.")
                }
            }
        }
    }

    private func overview(spending: [PersistentIdentifier: Decimal]) -> some View {
        let budgeted = categories.filter(\.hasBudget)
        let totalBudget = budgeted.reduce(0) { $0 + $1.monthlyBudget }
        let spentInBudgeted = budgeted.reduce(0) { $0 + (spending[$1.persistentModelID] ?? 0) }
        let overBudget = budgeted.filter { (spending[$0.persistentModelID] ?? 0) > $0.monthlyBudget }.count

        return HStack(spacing: 12) {
            StatTile(title: "Categories", value: "\(categories.count)", icon: "square.grid.2x2.fill", tint: .indigo)
            StatTile(
                title: "Budget used",
                value: totalBudget > 0
                    ? (spentInBudgeted / totalBudget).doubleValue.formatted(.percent.precision(.fractionLength(0)))
                    : "—",
                icon: "gauge.with.dots.needle.33percent",
                tint: .teal
            )
            StatTile(title: "Over budget", value: "\(overBudget)", icon: "exclamationmark.triangle.fill",
                     tint: overBudget > 0 ? .red : .green)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
        try? context.save()
    }

    private func delete(_ category: ExpenseCategory, includingExpenses: Bool) {
        withAnimation {
            if includingExpenses {
                for expense in category.expenses ?? [] {
                    context.delete(expense)
                }
            }
            context.delete(category)
            try? context.save()
        }
    }
}

struct CategoryRow: View {
    let category: ExpenseCategory
    let spent: Decimal
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(category.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(spent.formattedCurrency(currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                if category.hasBudget {
                    BudgetBar(progress: (spent / category.monthlyBudget).doubleValue, tint: category.color, height: 6)
                    budgetCaption
                } else {
                    Text("\(category.expenseCount) \(category.expenseCount == 1 ? "expense" : "expenses") · No budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var budgetCaption: some View {
        let remaining = category.monthlyBudget - spent
        return Text(remaining >= 0
                    ? "\(remaining.formattedCurrency(currency)) left of \(category.monthlyBudget.formattedCurrency(currency))"
                    : "\((-remaining).formattedCurrency(currency)) over budget")
            .font(.caption)
            .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .card(padding: 12)
    }
}
