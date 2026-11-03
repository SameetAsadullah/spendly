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
    @State private var showingExpenses: ExpenseCategory?
    @State private var pendingDelete: ExpenseCategory?

    private struct MonthTotals {
        var spent: [PersistentIdentifier: Decimal] = [:]
        var count: [PersistentIdentifier: Int] = [:]
        /// Includes expenses without a category.
        var total: Decimal = 0
    }

    private var monthTotals: MonthTotals {
        let month = Calendar.current.monthInterval(for: .now)
        var totals = MonthTotals()
        for expense in expenses where month.containsHalfOpen(expense.date) {
            totals.total += expense.amount
            if let id = expense.category?.persistentModelID {
                totals.spent[id, default: 0] += expense.amount
                totals.count[id, default: 0] += 1
            }
        }
        return totals
    }

    private func sorted(_ categories: [ExpenseCategory], by spent: [PersistentIdentifier: Decimal]) -> [ExpenseCategory] {
        categories.sorted { lhs, rhs in
            let left = spent[lhs.persistentModelID] ?? 0
            let right = spent[rhs.persistentModelID] ?? 0
            if left != right { return left > right }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        let totals = monthTotals

        NavigationStack {
            List {
                if !categories.isEmpty {
                    Section {
                        overview(totals: totals)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                    Section {
                        ForEach(sorted(categories, by: totals.spent)) { category in
                            Button {
                                editingCategory = category
                            } label: {
                                CategoryRow(
                                    category: category,
                                    spent: totals.spent[category.persistentModelID] ?? 0,
                                    monthCount: totals.count[category.persistentModelID] ?? 0,
                                    currency: currency
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = category
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button { editingCategory = category } label: { Label("Edit", systemImage: "pencil") }
                                Button { showingExpenses = category } label: { Label("Show Expenses", systemImage: "list.bullet") }
                                Button(role: .destructive) { pendingDelete = category } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    } header: {
                        Text(Date.now.formatted(.dateTime.month(.wide)))
                    } footer: {
                        Text("Tap to edit. Swipe left to delete.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .navigationDestination(item: $showingExpenses) { category in
                ExpenseListView(title: category.name, filter: .category(category))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Category")
                }
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No Categories", systemImage: "folder")
                    } description: {
                        Text("Create categories like Food, Rent or Travel to organize your expenses.")
                    } actions: {
                        Button("Add Suggested Categories") {
                            SampleData.insertDefaultCategories(in: context)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Add Category") { showNewCategory = true }
                            .buttonStyle(.bordered)
                        Text("Suggested categories are \(SampleData.defaultCategories.count) common ones such as Food & Dining, Groceries and Transport. You can edit or delete them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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
                "Delete “\(pendingDelete?.name ?? "category")”?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { category in
                let count = category.expenseCount
                if count > 0 {
                    Button("Delete Category Only", role: .destructive) {
                        delete(category, includingExpenses: false)
                    }
                    Button("Delete Category and \(count) \(count == 1 ? "Expense" : "Expenses")", role: .destructive) {
                        delete(category, includingExpenses: true)
                    }
                } else {
                    Button("Delete Category", role: .destructive) {
                        delete(category, includingExpenses: false)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { category in
                let count = category.expenseCount
                if count > 0 {
                    Text("\(count) \(count == 1 ? "expense uses" : "expenses use") this category. Keep them as Uncategorized, or delete them with the category.")
                } else {
                    Text("This category has no expenses.")
                }
            }
        }
    }

    private func overview(totals: MonthTotals) -> some View {
        let budgeted = categories.filter(\.hasBudget)
        let overBudget = budgeted.filter { (totals.spent[$0.persistentModelID] ?? 0) > $0.monthlyBudget }.count

        return StatTileRow {
            StatTile(icon: "square.grid.2x2", value: "\(categories.count)", label: "Categories")
            StatTile(
                icon: "dollarsign.circle",
                value: totals.total.formattedCurrency(currency, fractionDigits: 0),
                label: "Spent in \(Date.now.formatted(.dateTime.month(.abbreviated)))"
            )
            StatTile(
                icon: "exclamationmark.triangle",
                value: budgeted.isEmpty ? "—" : "\(overBudget) of \(budgeted.count)",
                label: "Budgets over",
                tint: overBudget > 0 ? .red : .accentColor
            )
        }
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
    let monthCount: Int
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(category.name)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(money(spent))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("\(monthCount) \(monthCount == 1 ? "expense" : "expenses")")
                    Spacer(minLength: 8)
                    budgetCaption
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if category.hasBudget {
                    BudgetBar(progress: (spent / category.monthlyBudget).doubleValue, tint: category.color, height: 6)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var budgetCaption: some View {
        if !category.hasBudget {
            Text("No budget")
        } else if spent > category.monthlyBudget {
            Text("\(money(spent - category.monthlyBudget)) over \(money(category.monthlyBudget))")
                .foregroundStyle(Color.red)
        } else {
            let percent = (spent / category.monthlyBudget).doubleValue.formatted(.percent.precision(.fractionLength(0)))
            Text("\(percent) of \(money(category.monthlyBudget))")
        }
    }

    /// Cents only when the amount has them.
    private func money(_ amount: Decimal) -> String {
        let isWhole = amount == Decimal(Int(truncating: NSDecimalNumber(decimal: amount)))
        return amount.formattedCurrency(currency, fractionDigits: isWhole ? 0 : nil)
    }
}

#if DEBUG
#Preview("Default, light") {
    CategoryListView().modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("Default, dark") {
    CategoryListView().modelContainer(PreviewData.container).previewVariant(.dark)
}

#Preview("Default, accessibility3") {
    CategoryListView().modelContainer(PreviewData.container).previewVariant(.accessibility)
}

#Preview("Empty, light") {
    CategoryListView().modelContainer(PreviewData.blankContainer).previewVariant(.light)
}

#Preview("Empty, dark") {
    CategoryListView().modelContainer(PreviewData.blankContainer).previewVariant(.dark)
}

#Preview("Empty, accessibility3") {
    CategoryListView().modelContainer(PreviewData.blankContainer).previewVariant(.accessibility)
}
#endif
