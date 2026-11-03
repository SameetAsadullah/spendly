import SwiftData
import SwiftUI

struct TrendsView: View {
    enum Period: Int, CaseIterable, Identifiable {
        case sixMonths = 6
        case twelveMonths = 12

        var id: Int { rawValue }
        var title: String { "\(rawValue) Months" }
    }

    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    let endMonth: Date
    @State private var period: Period = .sixMonths
    /// nil means all categories.
    @State private var categoryID: PersistentIdentifier?
    /// nil means all subcategories of the chosen category.
    @State private var subcategoryID: PersistentIdentifier?

    /// `category` presets the Category picker; pass a main category.
    init(endMonth: Date, category: ExpenseCategory? = nil) {
        self.endMonth = endMonth
        _categoryID = State(initialValue: category?.mainCategory.persistentModelID)
    }

    private var selectedCategory: ExpenseCategory? {
        categories.first { $0.persistentModelID == categoryID }
    }

    private var selectedSubcategory: ExpenseCategory? {
        selectedCategory?.sortedSubcategories.first { $0.persistentModelID == subcategoryID }
    }

    /// The narrowest category the screen is scoped to.
    private var scopeCategory: ExpenseCategory? { selectedSubcategory ?? selectedCategory }

    /// The chosen category when its bars are stacked by subcategory.
    private var stackedCategory: ExpenseCategory? {
        guard let selectedCategory, selectedCategory.hasSubcategories, selectedSubcategory == nil else { return nil }
        return selectedCategory
    }

    private func scopedExpenses() -> [Expense] {
        if let selectedSubcategory {
            return expenses.filter { $0.category?.persistentModelID == selectedSubcategory.persistentModelID }
        }
        guard categoryID != nil else { return expenses }
        return expenses.filter { $0.category?.mainCategory.persistentModelID == categoryID }
    }

    var body: some View {
        let scoped = scopedExpenses()
        let totals = MonthlyTrend.totals(for: scoped, monthsEndingAt: endMonth, count: period.rawValue)
        let total = totals.reduce(0) { $0 + $1.total }
        let highest = totals.filter { $0.total > 0 }.max { $0.total < $1.total }

        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Category", selection: $categoryID) {
                    Text("All Categories").tag(PersistentIdentifier?.none)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.iconName)
                            .tag(Optional(category.persistentModelID))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: categoryID) { subcategoryID = nil }

                if let selectedCategory, selectedCategory.hasSubcategories {
                    Picker("Subcategory", selection: $subcategoryID) {
                        Text("All Subcategories").tag(PersistentIdentifier?.none)
                        ForEach(selectedCategory.sortedSubcategories) { subcategory in
                            Label(subcategory.name, systemImage: subcategory.iconName)
                                .tag(Optional(subcategory.persistentModelID))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section {
                StatTileRow {
                    StatTile(icon: "dollarsign.circle", value: total.formattedCurrency(currency, fractionDigits: 0),
                             label: "Total")
                    StatTile(icon: "calendar",
                             value: (total / Decimal(max(totals.count, 1))).formattedCurrency(currency, fractionDigits: 0),
                             label: "Monthly average", tint: .orange)
                    StatTile(icon: "arrow.up.circle",
                             value: (highest?.total ?? 0).formattedCurrency(currency, fractionDigits: 0),
                             label: highest.map { "Top month · \($0.month.formatted(.dateTime.month(.abbreviated)))" } ?? "Top month")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    CardHeader(title: "Monthly totals", subtitle: periodLabel(totals))
                    chart(totals: totals, scoped: scoped)
                }
                .card()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if let stackedCategory {
                subcategorySection(for: stackedCategory, scoped: scoped)
            }

            Section {
                ForEach(Array(totals.enumerated().reversed()), id: \.element.id) { index, item in
                    NavigationLink {
                        ExpenseListView(title: item.month.formatted(.dateTime.month(.wide).year()),
                                        filter: filter(for: item.month))
                    } label: {
                        MonthTrendRow(item: item,
                                      previousTotal: index > 0 ? totals[index - 1].total : nil,
                                      currency: currency)
                    }
                }
            } header: {
                Text("By Month")
            } footer: {
                Text("Change is against the month before. Red means you spent more, green means less.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func chart(totals: [MonthTotal], scoped: [Expense]) -> some View {
        let highlighted = Calendar.current.startOfMonth(for: endMonth)
        if let stackedCategory {
            SubcategoryTrendChart(
                totals: MonthlyTrend.subcategoryTotals(for: scoped, of: stackedCategory,
                                                       monthsEndingAt: endMonth, count: period.rawValue),
                series: MonthlyTrend.series(for: stackedCategory),
                currency: currency,
                highlightedMonth: highlighted
            )
        } else {
            MonthlyTrendChart(totals: totals, currency: currency, highlightedMonth: highlighted, tint: scopeTint)
        }
    }

    private var scopeTint: Color {
        guard let selectedSubcategory, let main = selectedCategory else { return selectedCategory?.color ?? .accentColor }
        return MonthlyTrend.series(for: main).first { $0.id == selectedSubcategory.persistentModelID }?.color ?? main.color
    }

    /// "No subcategory" is not tappable: the Subcategory picker has no entry for it.
    private func subcategorySection(for main: ExpenseCategory, scoped: [Expense]) -> some View {
        let totals = MonthlyTrend.subcategoryTotals(for: scoped, of: main, monthsEndingAt: endMonth, count: period.rawValue)
        let grand = totals.reduce(0) { $0 + $1.total }
        let rows = Dictionary(grouping: totals, by: \.series).map { series, items in
            (series: series, total: items.reduce(0) { $0 + $1.total })
        }
        .filter { !$0.series.isRemainder || $0.total > 0 }
        .sorted { $0.series.isRemainder != $1.series.isRemainder ? !$0.series.isRemainder : $0.total > $1.total }

        return Section {
            ForEach(rows, id: \.series.id) { row in
                let content = SubcategoryTrendRow(series: row.series, total: row.total, grand: grand,
                                             monthCount: period.rawValue, currency: currency)
                if row.series.isRemainder {
                    content
                } else {
                    Button {
                        withAnimation(.snappy) { subcategoryID = row.series.id }
                    } label: {
                        content
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("By Subcategory · \(period.rawValue) Months")
        }
    }

    private func periodLabel(_ totals: [MonthTotal]) -> String {
        guard let first = totals.first?.month, let last = totals.last?.month else { return "" }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).year()
        return "\(first.formatted(style)) – \(last.formatted(style)) · \(scopeCategory?.path ?? "All Categories")"
    }

    private func filter(for month: Date) -> ExpenseFilter {
        var filter = scopeCategory.map { ExpenseFilter.category($0) } ?? ExpenseFilter()
        filter.restrict(toMonthOf: month)
        return filter
    }
}

private struct SubcategoryTrendRow: View {
    let series: SubcategorySeries
    let total: Decimal
    let grand: Decimal
    let monthCount: Int
    let currency: String

    var body: some View {
        let share = (total / max(grand, 1)).doubleValue.formatted(.percent.precision(.fractionLength(0)))
        let average = (total / Decimal(monthCount)).formattedCurrency(currency, fractionDigits: 0)

        HStack(spacing: 10) {
            Circle()
                .fill(series.color)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(series.name)
                    .font(.subheadline.weight(.medium))
                Text("\(share) · \(average) a month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(total.formattedCurrency(currency))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            if !series.isRemainder {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct MonthTrendRow: View {
    let item: MonthTotal
    let previousTotal: Decimal?
    let currency: String

    private var change: Double? {
        guard let previousTotal, previousTotal > 0 else { return nil }
        return ((item.total - previousTotal) / previousTotal).doubleValue
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.month, format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.medium))
                Text("\(item.count) \(item.count == 1 ? "expense" : "expenses")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.total.formattedCurrency(currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let change {
                    let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
                    Label(percent, systemImage: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change > 0 ? Color.red : Color.green)
                        .accessibilityLabel("\(change > 0 ? "Up" : "Down") \(percent) versus the month before")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
@MainActor
private func previewCategory(_ name: String) -> ExpenseCategory? {
    let categories = (try? PreviewData.container.mainContext.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
    return categories.first { $0.name == name && !$0.isSubcategory }
}

#Preview("Default · Light") {
    NavigationStack { TrendsView(endMonth: .now) }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Default · Dark") {
    NavigationStack { TrendsView(endMonth: .now) }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Food & Dining · Light") {
    NavigationStack { TrendsView(endMonth: .now, category: previewCategory("Food & Dining")) }
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Food & Dining · Dark") {
    NavigationStack { TrendsView(endMonth: .now, category: previewCategory("Food & Dining")) }
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Default · Accessibility 3") {
    NavigationStack { TrendsView(endMonth: .now) }
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}
#endif
