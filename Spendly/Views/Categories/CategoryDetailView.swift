import SwiftData
import SwiftUI

struct CategoryDetailView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    let category: ExpenseCategory
    @State private var month: Date
    @State private var showEditor = false
    @State private var showNewSubcategory = false
    @State private var expenseRoute: ExpenseEditorRoute?

    init(category: ExpenseCategory, month: Date = .now) {
        self.category = category
        _month = State(initialValue: Calendar.current.startOfMonth(for: month))
    }

    private struct SubcategoryRow: Identifiable {
        let id: PersistentIdentifier
        let category: ExpenseCategory
        let isRemainder: Bool
        let name: String
        let iconName: String
        let color: Color
        let total: Decimal
        let count: Int
        let budget: Decimal
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private var previousMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
    }

    var body: some View {
        let mainID = category.persistentModelID
        let scoped = expenses.filter { $0.category?.mainCategory.persistentModelID == mainID }
        let summary = MonthSummary(allExpenses: scoped, month: month)

        ScrollView {
            VStack(spacing: 16) {
                monthSwitcher
                summaryCard(summary)
                statsRow(summary)
                subcategoryCard(summary)
                trendCard(scoped)
                if summary.count > 0 {
                    recentCard(summary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            CategoryEditorView(category: category)
        }
        .sheet(isPresented: $showNewSubcategory) {
            SubcategoryEditorView(parent: category)
        }
        .sheet(item: $expenseRoute) { route in
            ExpenseEditorView(route: route)
        }
    }

    // MARK: Header

    private var monthSwitcher: some View {
        HStack(spacing: 12) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("Previous month")

            Text(month, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.35 : 1)
            .accessibilityLabel("Next month")
        }
        .padding(.top, 4)
    }

    private func summaryCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CategoryIcon(category: category, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCurrentMonth ? "Spent this month" : "Spent in \(month.formatted(.dateTime.month(.wide)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(summary.total.formattedCurrency(currency))
                        .font(.listTotalAmount)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
            }
            changeCaption(summary)
            if category.hasBudget {
                budgetProgress(summary)
            }
        }
        .card()
    }

    @ViewBuilder
    private func changeCaption(_ summary: MonthSummary) -> some View {
        let previous = previousMonth.formatted(.dateTime.month(.abbreviated))
        if let change = summary.changeRatio {
            let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
            Label("\(percent) vs \(previous)", systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(change > 0 ? Color.red : Color.green)
                .accessibilityLabel("\(change > 0 ? "Up" : "Down") \(percent) versus \(previousMonth.formatted(.dateTime.month(.wide)))")
        } else {
            Text("Nothing to compare in \(previous)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func budgetProgress(_ summary: MonthSummary) -> some View {
        let budget = category.monthlyBudget
        let remaining = budget - summary.total

        return VStack(alignment: .leading, spacing: 6) {
            BudgetBar(progress: (summary.total / budget).doubleValue, tint: category.color, height: 8)
            ViewThatFits(in: .horizontal) {
                HStack {
                    budgetStatus(remaining: remaining)
                    Spacer(minLength: 8)
                    Text("of \(budget.formattedCurrency(currency))")
                }
                VStack(alignment: .leading, spacing: 2) {
                    budgetStatus(remaining: remaining)
                    Text("of \(budget.formattedCurrency(currency))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func budgetStatus(remaining: Decimal) -> some View {
        if remaining < 0 {
            Label("\((-remaining).formattedCurrency(currency)) over budget", systemImage: "exclamationmark.triangle.fill")
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        } else {
            Text("\(remaining.formattedCurrency(currency)) left")
                .fontWeight(.semibold)
        }
    }

    private func statsRow(_ summary: MonthSummary) -> some View {
        StatTileRow {
            StatTile(icon: "list.bullet", value: "\(summary.count)", label: "Expenses", tint: category.color)
            StatTile(icon: "calendar", value: summary.dailyAverage.formattedCurrency(currency, fractionDigits: 0),
                     label: "Daily average", tint: category.color)
            StatTile(icon: "arrow.up.circle", value: (summary.largest?.amount ?? 0).formattedCurrency(currency, fractionDigits: 0),
                     label: "Largest", tint: category.color)
        }
    }

    // MARK: Subcategories

    private func rows(_ summary: MonthSummary) -> [SubcategoryRow] {
        let slices = summary.slices.first?.subslices ?? []
        let series = MonthlyTrend.series(for: category)
        let subcategories = category.sortedSubcategories.map { sub in
            let slice = slices.first { $0.id == sub.persistentModelID && !$0.isRemainder }
            return SubcategoryRow(
                id: sub.persistentModelID, category: sub, isRemainder: false, name: sub.name, iconName: sub.iconName,
                color: series.first { $0.id == sub.persistentModelID }?.color ?? category.color,
                total: slice?.total ?? 0, count: slice?.count ?? 0, budget: sub.monthlyBudget
            )
        }
        .sorted { $0.total > $1.total }

        let direct = slices.first { $0.isRemainder }
        let remainder = SubcategoryRow(
            id: category.persistentModelID, category: category, isRemainder: true, name: "No subcategory",
            iconName: category.iconName, color: Theme.uncategorized,
            total: direct?.total ?? 0, count: direct?.count ?? 0, budget: 0
        )
        return subcategories + [remainder]
    }

    private func subcategoryCard(_ summary: MonthSummary) -> some View {
        let rows = category.hasSubcategories ? rows(summary) : []
        let count = category.subcategories?.count ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "By Subcategory", subtitle: "\(count) \(count == 1 ? "subcategory" : "subcategories")")

            if category.hasSubcategories {
                if summary.total > 0 {
                    stackedBar(rows, total: summary.total)
                }
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        NavigationLink {
                            ExpenseListView(title: row.isRemainder ? "\(category.name) › No subcategory" : row.category.path,
                                            filter: monthFilter(for: row))
                        } label: {
                            subcategoryRow(row, total: summary.total)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Split \(category.name) into subcategories such as Coffee or Fuel to see where it goes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showNewSubcategory = true
            } label: {
                Label("Add Subcategory", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .card()
    }

    private func stackedBar(_ rows: [SubcategoryRow], total: Decimal) -> some View {
        let shown = rows.filter { $0.total > 0 }

        return GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(shown) { row in
                    Capsule()
                        .fill(row.color)
                        .frame(width: max(geometry.size.width * (row.total / total).doubleValue - 2, 4))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func subcategoryRow(_ row: SubcategoryRow, total: Decimal) -> some View {
        let share = (row.total / max(total, 1)).doubleValue.formatted(.percent.precision(.fractionLength(0)))
        let progress = row.budget > 0 ? (row.total / row.budget).doubleValue : 0

        return HStack(alignment: .top, spacing: 10) {
            CategoryIcon(iconName: row.iconName, color: row.color, size: 26)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 8)
                    Text(row.total.formattedCurrency(currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                Text("\(share) · \(row.count) \(row.count == 1 ? "expense" : "expenses")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if row.budget > 0 {
                    BudgetBar(progress: progress, tint: row.color, height: 6)
                        .padding(.top, 2)
                    if progress > 1 {
                        Text("\((row.total - row.budget).formattedCurrency(currency)) over \(row.budget.formattedCurrency(currency, fractionDigits: 0))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text("\(progress.formatted(.percent.precision(.fractionLength(0)))) of \(row.budget.formattedCurrency(currency, fractionDigits: 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: Trend and recent

    private func trendCard(_ scoped: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Last 6 months") {
                NavigationLink {
                    TrendsView(endMonth: month, category: category)
                } label: {
                    Text("See all")
                }
            }
            if category.hasSubcategories {
                SubcategoryTrendChart(
                    totals: MonthlyTrend.subcategoryTotals(for: scoped, of: category, monthsEndingAt: month, count: 6),
                    series: MonthlyTrend.series(for: category),
                    currency: currency,
                    highlightedMonth: month,
                    showsAxis: false,
                    height: 150
                )
            } else {
                MonthlyTrendChart(
                    totals: MonthlyTrend.totals(for: scoped, monthsEndingAt: month, count: 6),
                    currency: currency,
                    highlightedMonth: month,
                    style: .compact,
                    height: 150
                )
            }
        }
        .card()
    }

    private func recentCard(_ summary: MonthSummary) -> some View {
        let recent = Array(summary.expenses.prefix(5))

        return VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Recent") {
                NavigationLink {
                    ExpenseListView(title: category.name, filter: monthFilter(for: nil))
                } label: {
                    Text("See all")
                }
            }
            ForEach(recent) { expense in
                Button {
                    expenseRoute = .edit(expense)
                } label: {
                    ExpenseRow(expense: expense, currency: currency, showsDay: true)
                }
                .buttonStyle(.plain)
                if expense.persistentModelID != recent.last?.persistentModelID {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .card()
    }

    // MARK: Helpers

    private func shiftMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) {
            month = Calendar.current.startOfMonth(for: next)
        }
    }

    /// nil filters the whole category, a row narrows it to that subcategory or to "No subcategory".
    private func monthFilter(for row: SubcategoryRow?) -> ExpenseFilter {
        var filter = ExpenseFilter.category(category)
        if let row {
            filter.subcategoryIDs[category.persistentModelID] = [row.id]
        }
        filter.restrict(toMonthOf: month)
        return filter
    }
}

#if DEBUG
@MainActor private struct CategoryDetailPreview: View {
    var variant: PreviewVariant
    var hasSubcategories = true

    var body: some View {
        let categories = (try? PreviewData.container.mainContext
            .fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let category = categories.first { $0.hasSubcategories == hasSubcategories && !$0.isSubcategory }
        NavigationStack {
            if let category {
                CategoryDetailView(category: category)
            }
        }
        .modelContainer(PreviewData.container)
        .previewVariant(variant)
    }
}

#Preview("With subcategories, light") { CategoryDetailPreview(variant: .light) }
#Preview("With subcategories, dark") { CategoryDetailPreview(variant: .dark) }
#Preview("No subcategories, light") { CategoryDetailPreview(variant: .light, hasSubcategories: false) }
#Preview("No subcategories, dark") { CategoryDetailPreview(variant: .dark, hasSubcategories: false) }
#endif
