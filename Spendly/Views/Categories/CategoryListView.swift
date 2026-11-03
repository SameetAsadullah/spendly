import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var allCategories: [ExpenseCategory]
    @Query private var expenses: [Expense]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    @State private var showNewCategory = false
    @State private var editingCategory: ExpenseCategory?
    @State private var editingSubcategory: ExpenseCategory?
    @State private var newSubcategoryParent: ExpenseCategory?
    @State private var detailCategory: ExpenseCategory?
    @State private var showingExpenses: ExpenseCategory?
    @State private var pendingDelete: ExpenseCategory?
    @State private var expanded: Set<PersistentIdentifier> = []

    private var categories: [ExpenseCategory] { allCategories.filter { !$0.isSubcategory } }

    private struct MonthTotals {
        /// A main category's entries include its subcategories.
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
            guard let category = expense.category else { continue }
            for id in Set([category.persistentModelID, category.mainCategory.persistentModelID]) {
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
                            mainRow(category, totals: totals)
                            if expanded.contains(category.persistentModelID) {
                                ForEach(sorted(category.sortedSubcategories, by: totals.spent)) { subcategory in
                                    subcategoryRow(subcategory, totals: totals)
                                }
                                addSubcategoryRow(category)
                            }
                        }
                    } header: {
                        Text(Date.now.formatted(.dateTime.month(.wide)))
                    } footer: {
                        Text("Tap to open. Swipe left to delete.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Categories")
            .navigationDestination(item: $detailCategory) { category in
                CategoryDetailView(category: category)
            }
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
            .sheet(item: $editingSubcategory) { subcategory in
                SubcategoryEditorView(subcategory: subcategory)
            }
            .sheet(item: $newSubcategoryParent) { parent in
                SubcategoryEditorView(parent: parent) { saved in
                    withAnimation { _ = expanded.insert(saved.mainCategory.persistentModelID) }
                }
            }
            .categoryDeleteDialog($pendingDelete)
        }
    }

    private func mainRow(_ category: ExpenseCategory, totals: MonthTotals) -> some View {
        let id = category.persistentModelID
        let isOpen = expanded.contains(id)

        return HStack(spacing: 8) {
            Button {
                detailCategory = category
            } label: {
                CategoryRow(
                    category: category,
                    spent: totals.spent[id] ?? 0,
                    monthCount: totals.count[id] ?? 0,
                    currency: currency
                )
            }
            .buttonStyle(.plain)

            if category.hasSubcategories {
                Button {
                    withAnimation(.snappy) {
                        if isOpen { expanded.remove(id) } else { expanded.insert(id) }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Hide subcategories" : "Show subcategories")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = category
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { detailCategory = category } label: { Label("Open", systemImage: "chevron.right") }
            Button { editingCategory = category } label: { Label("Edit", systemImage: "pencil") }
            Button { newSubcategoryParent = category } label: { Label("Add Subcategory", systemImage: "plus") }
            Button { showingExpenses = category } label: { Label("Show Expenses", systemImage: "list.bullet") }
            Button(role: .destructive) { pendingDelete = category } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func subcategoryRow(_ subcategory: ExpenseCategory, totals: MonthTotals) -> some View {
        Button {
            editingSubcategory = subcategory
        } label: {
            SubcategoryRow(
                subcategory: subcategory,
                spent: totals.spent[subcategory.persistentModelID] ?? 0,
                monthCount: totals.count[subcategory.persistentModelID] ?? 0,
                currency: currency
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = subcategory
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { editingSubcategory = subcategory } label: { Label("Edit", systemImage: "pencil") }
            Button { showingExpenses = subcategory } label: { Label("Show Expenses", systemImage: "list.bullet") }
            Button(role: .destructive) { pendingDelete = subcategory } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func addSubcategoryRow(_ category: ExpenseCategory) -> some View {
        Button {
            newSubcategoryParent = category
        } label: {
            Label("Add Subcategory", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.leading, SubcategoryRow.indent)
                .padding(.vertical, 2)
        }
    }

    private func overview(totals: MonthTotals) -> some View {
        let subcategories = categories.flatMap { $0.subcategories ?? [] }
        let budgeted = (categories + subcategories).filter(\.hasBudget)
        let overBudget = budgeted.filter { (totals.spent[$0.persistentModelID] ?? 0) > $0.monthlyBudget }.count

        return StatTileRow {
            StatTile(icon: "square.grid.2x2", value: "\(categories.count)", label: "Categories")
            StatTile(icon: "square.split.2x1", value: "\(subcategories.count)", label: "Subcategories")
            StatTile(
                icon: "exclamationmark.triangle",
                value: budgeted.isEmpty ? "—" : "\(overBudget) of \(budgeted.count)",
                label: "Budgets over",
                tint: overBudget > 0 ? .red : .accentColor
            )
        }
    }
}

/// Cents only when the amount has them.
private func money(_ amount: Decimal, in currency: String) -> String {
    let isWhole = amount == Decimal(Int(truncating: NSDecimalNumber(decimal: amount)))
    return amount.formattedCurrency(currency, fractionDigits: isWhole ? 0 : nil)
}

/// The budget line shared by main and subcategory rows.
private struct BudgetCaption: View {
    let category: ExpenseCategory
    let spent: Decimal
    let currency: String

    var body: some View {
        if !category.hasBudget {
            Text("No budget")
        } else if spent > category.monthlyBudget {
            Text("\(money(spent - category.monthlyBudget, in: currency)) over \(money(category.monthlyBudget, in: currency))")
                .foregroundStyle(Color.red)
        } else {
            let percent = (spent / category.monthlyBudget).doubleValue.formatted(.percent.precision(.fractionLength(0)))
            Text("\(percent) of \(money(category.monthlyBudget, in: currency))")
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
                    Text(money(spent, in: currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(caption)
                    Spacer(minLength: 8)
                    BudgetCaption(category: category, spent: spent, currency: currency)
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

    private var caption: String {
        let expenses = "\(monthCount) \(monthCount == 1 ? "expense" : "expenses")"
        let count = category.subcategories?.count ?? 0
        guard count > 0 else { return expenses }
        return "\(expenses) · \(count) \(count == 1 ? "subcategory" : "subcategories")"
    }
}

struct SubcategoryRow: View {
    static let indent: CGFloat = 20

    let subcategory: ExpenseCategory
    let spent: Decimal
    let monthCount: Int
    let currency: String

    var body: some View {
        HStack(spacing: 10) {
            CategoryIcon(category: subcategory, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(subcategory.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(money(spent, in: currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("\(monthCount) \(monthCount == 1 ? "expense" : "expenses")")
                    Spacer(minLength: 8)
                    if subcategory.hasBudget {
                        BudgetCaption(category: subcategory, spent: spent, currency: currency)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if subcategory.hasBudget {
                    BudgetBar(progress: (spent / subcategory.monthlyBudget).doubleValue, tint: subcategory.color, height: 6)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.leading, Self.indent)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
