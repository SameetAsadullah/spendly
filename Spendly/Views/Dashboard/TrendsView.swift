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

    private var selectedCategory: ExpenseCategory? {
        categories.first { $0.persistentModelID == categoryID }
    }

    var body: some View {
        let scoped = categoryID == nil ? expenses : expenses.filter { $0.category?.persistentModelID == categoryID }
        let totals = MonthlyTrend.totals(for: scoped, monthsEndingAt: endMonth, count: period.rawValue)
        let total = totals.reduce(0) { $0 + $1.total }
        let highest = totals.filter { $0.total > 0 }.max { $0.total < $1.total }

        ScrollView {
            VStack(spacing: 16) {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                StatTileRow {
                    StatTile(icon: "dollarsign.circle", value: total.formattedCurrency(currency, fractionDigits: 0),
                             label: "Total")
                    StatTile(icon: "calendar",
                             value: (total / Decimal(totals.count)).formattedCurrency(currency, fractionDigits: 0),
                             label: "Monthly average", tint: .orange)
                    StatTile(icon: "arrow.up.circle",
                             value: (highest?.total ?? 0).formattedCurrency(currency, fractionDigits: 0),
                             label: highest.map { "Top month · \($0.month.formatted(.dateTime.month(.abbreviated)))" } ?? "Top month")
                }

                VStack(alignment: .leading, spacing: 14) {
                    CardHeader(title: selectedCategory?.name ?? "All Categories", subtitle: periodLabel(totals))
                    MonthlyTrendChart(totals: totals, currency: currency)
                }
                .card()

                monthsCard(totals)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                categoryMenu
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $categoryID) {
                Text("All Categories").tag(PersistentIdentifier?.none)
                ForEach(categories) { category in
                    Label(category.name, systemImage: category.iconName)
                        .tag(Optional(category.persistentModelID))
                }
            }
        } label: {
            Label("Category", systemImage: categoryID == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func monthsCard(_ totals: [MonthTotal]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CardHeader(title: "By Month", subtitle: nil)
                .padding(.bottom, 8)
            ForEach(Array(totals.enumerated().reversed()), id: \.element.id) { index, item in
                NavigationLink {
                    ExpenseListView(title: item.month.formatted(.dateTime.month(.wide).year()),
                                    filter: filter(for: item.month))
                } label: {
                    MonthTrendRow(item: item,
                                  previousTotal: index > 0 ? totals[index - 1].total : nil,
                                  currency: currency)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func periodLabel(_ totals: [MonthTotal]) -> String {
        guard let first = totals.first?.month, let last = totals.last?.month else { return "" }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).year()
        return "\(first.formatted(style)) – \(last.formatted(style))"
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
            VStack(alignment: .leading, spacing: 1) {
                Text(item.month, format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                Text("\(item.count) \(item.count == 1 ? "expense" : "expenses")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(item.total.formattedCurrency(currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                if let change {
                    Label(abs(change).formatted(.percent.precision(.fractionLength(0))),
                          systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change > 0 ? Color.red : Color.green)
                        .accessibilityLabel("\(change > 0 ? "Up" : "Down") \(abs(change).formatted(.percent.precision(.fractionLength(0)))) versus the month before")
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        TrendsView(endMonth: .now)
    }
    .modelContainer(PreviewData.container)
}
