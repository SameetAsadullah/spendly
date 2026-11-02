import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @AppStorage(AppSettings.monthlyBudgetKey) private var storedMonthlyBudget = 0.0

    @State private var month = Calendar.current.startOfMonth(for: .now)
    @State private var editorRoute: ExpenseEditorRoute?

    private var monthlyBudget: Decimal { Decimal(roundTripping: storedMonthlyBudget) }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        let summary = MonthSummary(allExpenses: expenses, month: month)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthSwitcher
                    heroCard(summary)
                    statsRow(summary)

                    if summary.count == 0 {
                        emptyMonthCard
                    } else {
                        categoryCard(summary)
                        dailyCard(summary)
                        budgetsCard(summary)
                        recentCard(summary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isCurrentMonth {
                        Button("Today") {
                            withAnimation(.snappy) { month = Calendar.current.startOfMonth(for: .now) }
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .sheet(item: $editorRoute) { route in
                ExpenseEditorView(route: route)
            }
        }
    }

    // MARK: Header

    private var monthSwitcher: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("Previous month")

            Spacer()

            VStack(spacing: 0) {
                Text(month, format: .dateTime.month(.wide))
                    .font(.title3.weight(.bold))
                Text(month, format: .dateTime.year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.opacity)

            Spacer()

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

    private func heroCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isCurrentMonth ? "Spent this month" : "Spent in \(month.formatted(.dateTime.month(.wide)))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if let change = summary.changeRatio {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(abs(change).formatted(.percent.precision(.fractionLength(0))))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
                    .accessibilityLabel("\(change > 0 ? "Up" : "Down") \(abs(change).formatted(.percent.precision(.fractionLength(0)))) versus last month")
                }
            }

            Text(summary.total.formattedCurrency(currency))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if monthlyBudget > 0 {
                let progress = (summary.total / monthlyBudget).doubleValue
                let remaining = monthlyBudget - summary.total
                VStack(alignment: .leading, spacing: 6) {
                    BudgetBar(progress: progress, tint: .white, height: 8)
                    HStack {
                        Text(remaining >= 0
                             ? "\(remaining.formattedCurrency(currency)) left"
                             : "\((-remaining).formattedCurrency(currency)) over budget")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("of \(monthlyBudget.formattedCurrency(currency))")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Text(summary.previousTotal > 0
                     ? "Last month: \(summary.previousTotal.formattedCurrency(currency))"
                     : "Set a monthly budget in Settings to track your limit.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.heroGradient
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .offset(x: 140, y: -70)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 160, height: 160)
                    .offset(x: -150, y: 80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(hex: "#4F46E5").opacity(0.3), radius: 16, y: 8)
    }

    private func statsRow(_ summary: MonthSummary) -> some View {
        HStack(spacing: 12) {
            StatTile(title: "Expenses", value: "\(summary.count)", icon: "list.bullet", tint: .indigo)
            StatTile(title: "Daily avg", value: summary.dailyAverage.formattedCurrency(currency, fractionDigits: 0),
                     icon: "calendar", tint: .orange)
            StatTile(title: "Largest", value: (summary.largest?.amount ?? 0).formattedCurrency(currency, fractionDigits: 0),
                     icon: "arrow.up.circle.fill", tint: .pink)
        }
    }

    // MARK: Cards

    private var emptyMonthCard: some View {
        ContentUnavailableView {
            Label("Nothing spent yet", systemImage: "sparkles")
        } description: {
            Text(expenses.isEmpty
                 ? "Tap + to add your first expense, or load sample data from Settings."
                 : "No expenses recorded in \(month.formatted(.dateTime.month(.wide).year())).")
        } actions: {
            Button("Add Expense") { editorRoute = .new }
                .buttonStyle(.borderedProminent)
        }
        .card()
    }

    private func categoryCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "By Category", subtitle: "\(summary.slices.count) categories")
            CategoryDonutChart(slices: summary.slices, total: summary.total, currency: currency)

            VStack(spacing: 2) {
                ForEach(summary.slices) { slice in
                    NavigationLink {
                        ExpenseListView(title: slice.name, filter: monthFilter(for: slice.category))
                    } label: {
                        HStack(spacing: 10) {
                            CategoryIcon(iconName: slice.iconName, color: slice.color, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(slice.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                Text("\(slice.count) \(slice.count == 1 ? "expense" : "expenses")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(slice.total.formattedCurrency(currency))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.primary)
                                Text((slice.total / max(summary.total, 1)).doubleValue.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func dailyCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Daily Spending",
                       subtitle: "avg \(summary.dailyAverage.formattedCurrency(currency)) per day")
            DailySpendingChart(
                daily: summary.daily,
                interval: summary.interval,
                average: summary.dailyAverage,
                currency: currency
            )
        }
        .card()
    }

    @ViewBuilder
    private func budgetsCard(_ summary: MonthSummary) -> some View {
        let budgeted = categories.filter(\.hasBudget)
        if !budgeted.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(title: "Budgets", subtitle: "Per-category limits")
                ForEach(budgeted) { category in
                    let spent = summary.spent(in: category)
                    let progress = (spent / category.monthlyBudget).doubleValue
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            CategoryIcon(category: category, size: 26)
                            Text(category.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(spent.formattedCurrency(currency, fractionDigits: 0)) / \(category.monthlyBudget.formattedCurrency(currency, fractionDigits: 0))")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(progress > 1 ? Color.red : Color.secondary)
                        }
                        BudgetBar(progress: progress, tint: category.color, height: 7)
                    }
                }
            }
            .card()
        }
    }

    private func recentCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardHeader(title: "Recent", subtitle: nil)
                Spacer()
                NavigationLink {
                    ExpenseListView(
                        title: month.formatted(.dateTime.month(.wide).year()),
                        filter: .month(month)
                    )
                } label: {
                    Text("See all").font(.subheadline.weight(.semibold))
                }
            }
            ForEach(summary.expenses.prefix(5)) { expense in
                Button {
                    editorRoute = .edit(expense)
                } label: {
                    ExpenseRow(expense: expense, currency: currency, showsDate: true)
                }
                .buttonStyle(.plain)
                if expense.persistentModelID != summary.expenses.prefix(5).last?.persistentModelID {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .card()
    }

    private var addButton: some View {
        Button {
            editorRoute = .new
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.heroGradient, in: Circle())
                .shadow(color: Color(hex: "#4F46E5").opacity(0.4), radius: 12, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Add expense")
    }

    // MARK: Helpers

    private func shiftMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) {
            month = Calendar.current.startOfMonth(for: next)
        }
    }

    private func monthFilter(for category: ExpenseCategory?) -> ExpenseFilter {
        var filter = ExpenseFilter.category(category)
        filter.restrict(toMonthOf: month)
        return filter
    }
}

struct CardHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
