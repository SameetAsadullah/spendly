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

    /// `category` presets the Category picker; pass a main category.
    init(endMonth: Date, category: ExpenseCategory? = nil) {
        self.endMonth = endMonth
        _categoryID = State(initialValue: category?.mainCategory.persistentModelID)
    }

    private var selectedCategory: ExpenseCategory? {
        categories.first { $0.persistentModelID == categoryID }
    }

    var body: some View {
        let scoped = categoryID == nil ? expenses : expenses.filter { $0.category?.mainCategory.persistentModelID == categoryID }
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
                    MonthlyTrendChart(totals: totals, currency: currency,
                                      highlightedMonth: Calendar.current.startOfMonth(for: endMonth))
                }
                .card()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
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

    private func periodLabel(_ totals: [MonthTotal]) -> String {
        guard let first = totals.first?.month, let last = totals.last?.month else { return "" }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).year()
        return "\(first.formatted(style)) – \(last.formatted(style)) · \(selectedCategory?.name ?? "All Categories")"
    }

    private func filter(for month: Date) -> ExpenseFilter {
        var filter = selectedCategory.map { ExpenseFilter.category($0) } ?? ExpenseFilter()
        filter.restrict(toMonthOf: month)
        return filter
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

#Preview("Default · Accessibility 3") {
    NavigationStack { TrendsView(endMonth: .now) }
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}
#endif
