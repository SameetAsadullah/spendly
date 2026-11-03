import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.selectTab) private var selectTab
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @AppStorage(AppSettings.monthlyBudgetKey) private var storedMonthlyBudget = 0.0

    @State private var month: Date
    @State private var editorRoute: ExpenseEditorRoute?

    init(month: Date = .now) {
        _month = State(initialValue: Calendar.current.startOfMonth(for: month))
    }

    private var monthlyBudget: Decimal { Decimal(roundTripping: storedMonthlyBudget) }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private var previousMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
    }

    var body: some View {
        let summary = MonthSummary(allExpenses: expenses, month: month)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if expenses.isEmpty {
                        noExpensesCard
                    } else {
                        monthSwitcher
                        heroCard(summary)

                        if summary.count == 0 {
                            emptyMonthCard
                        } else {
                            statsRow(summary)
                            dailyCard(summary)
                            trendCard
                            categoryCard(summary)
                            recentCard(summary)
                        }
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
                if !expenses.isEmpty {
                    addButton
                }
            }
            .sheet(item: $editorRoute) { route in
                ExpenseEditorView(route: route)
            }
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

    private func heroCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    heroLabel
                    Spacer(minLength: 8)
                    changeBadge(summary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    heroLabel
                    changeBadge(summary)
                }
            }

            Text(summary.total.formattedCurrency(currency))
                .font(.heroAmount)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if monthlyBudget > 0 {
                budgetProgress(summary)
            } else {
                noBudgetFooter(summary)
            }
        }
        .padding(Theme.Spacing.hero)
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
            // Clipping does not limit hit testing, so the circles would cover the month switcher.
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .heroShadow()
    }

    private var heroLabel: some View {
        Text(isCurrentMonth ? "Spent this month" : "Spent in \(month.formatted(.dateTime.month(.wide)))")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
    }

    @ViewBuilder
    private func changeBadge(_ summary: MonthSummary) -> some View {
        if let change = summary.changeRatio {
            let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
            HStack(spacing: 4) {
                Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(percent) vs \(previousMonth.formatted(.dateTime.month(.abbreviated)))")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(change > 0 ? "Up" : "Down") \(percent) versus \(previousMonth.formatted(.dateTime.month(.wide)))")
        }
    }

    private func budgetProgress(_ summary: MonthSummary) -> some View {
        let progress = (summary.total / monthlyBudget).doubleValue
        let remaining = monthlyBudget - summary.total
        let isOver = remaining < 0

        return VStack(alignment: .leading, spacing: 6) {
            BudgetBar(progress: progress, tint: .white, height: 8)
            ViewThatFits(in: .horizontal) {
                HStack {
                    budgetStatus(remaining: remaining, isOver: isOver)
                    Spacer(minLength: 8)
                    Text("of \(monthlyBudget.formattedCurrency(currency))")
                }
                VStack(alignment: .leading, spacing: 2) {
                    budgetStatus(remaining: remaining, isOver: isOver)
                    Text("of \(monthlyBudget.formattedCurrency(currency))")
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private func budgetStatus(remaining: Decimal, isOver: Bool) -> some View {
        if isOver {
            Label("\((-remaining).formattedCurrency(currency)) over budget", systemImage: "exclamationmark.triangle.fill")
                .fontWeight(.semibold)
        } else {
            Text("\(remaining.formattedCurrency(currency)) left")
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func noBudgetFooter(_ summary: MonthSummary) -> some View {
        if summary.previousTotal > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(height: 1)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(previousMonth, format: .dateTime.month(.wide))
                        Spacer(minLength: 8)
                        Text(summary.previousTotal.formattedCurrency(currency)).monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(previousMonth, format: .dateTime.month(.wide))
                        Text(summary.previousTotal.formattedCurrency(currency)).monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
        } else {
            Button {
                selectTab(.settings)
            } label: {
                Text("Set a monthly budget in Settings ›")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func statsRow(_ summary: MonthSummary) -> some View {
        StatTileRow {
            StatTile(icon: "list.bullet", value: "\(summary.count)", label: "Expenses")
            StatTile(icon: "calendar", value: summary.dailyAverage.formattedCurrency(currency, fractionDigits: 0),
                     label: "Daily average", tint: .orange)
            StatTile(icon: "arrow.up.circle", value: (summary.largest?.amount ?? 0).formattedCurrency(currency, fractionDigits: 0),
                     label: "Largest", tint: summary.largest?.category?.color ?? Theme.uncategorized)
        }
    }

    // MARK: Empty states

    private var noExpensesCard: some View {
        VStack(spacing: 12) {
            CategoryIcon(iconName: "chart.pie", color: .accentColor, size: 76)
            Text("No expenses yet")
                .font(.title3.weight(.bold))
            Text("Add your first expense to see your spending, budgets and trends here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                editorRoute = .new
            } label: {
                Text("Add Expense").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button {
                SampleData.insertSampleExpenses(in: context)
            } label: {
                Text("Load Sample Data").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("Delete All Expenses in Settings › Data removes it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Spacing.hero)
        .padding(.top, 8)
    }

    private var emptyMonthCard: some View {
        VStack(spacing: 12) {
            CategoryIcon(iconName: "calendar", color: .accentColor, size: 76)
            Text("No expenses in \(month.formatted(.dateTime.month(.wide)))")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Use the arrows above to switch to another month.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                editorRoute = .new
            } label: {
                Text("Add Expense").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Spacing.hero)
    }

    // MARK: Cards

    private func categoryCard(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "By Category", subtitle: "\(summary.slices.count) \(summary.slices.count == 1 ? "category" : "categories")")
            CategoryDonutChart(slices: summary.slices, total: summary.total, currency: currency)

            VStack(spacing: 8) {
                ForEach(summary.slices) { slice in
                    NavigationLink {
                        ExpenseListView(title: slice.name, filter: monthFilter(for: slice.category))
                    } label: {
                        categoryRow(slice, total: summary.total)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func categoryRow(_ slice: CategorySlice, total: Decimal) -> some View {
        let share = (slice.total / max(total, 1)).doubleValue.formatted(.percent.precision(.fractionLength(0)))
        let budget = slice.category?.monthlyBudget ?? 0
        let progress = budget > 0 ? (slice.total / budget).doubleValue : 0

        return HStack(alignment: .top, spacing: 10) {
            CategoryIcon(iconName: slice.iconName, color: slice.color, size: 26)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(slice.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 8)
                    Text(slice.total.formattedCurrency(currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                }
                Text("\(share) · \(slice.count) \(slice.count == 1 ? "expense" : "expenses")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if budget > 0 {
                    BudgetBar(progress: progress, tint: slice.color, height: 6)
                        .padding(.top, 2)
                    if progress > 1 {
                        Text("\((slice.total - budget).formattedCurrency(currency)) over \(budget.formattedCurrency(currency, fractionDigits: 0))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text("\(progress.formatted(.percent.precision(.fractionLength(0)))) of \(budget.formattedCurrency(currency, fractionDigits: 0))")
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

    private func dailyCard(_ summary: MonthSummary) -> some View {
        let lastDay = Calendar.current.date(byAdding: .day, value: summary.daysCounted - 1, to: summary.interval.start)
            ?? summary.interval.start
        let range = "\(summary.interval.start.formatted(.dateTime.month(.abbreviated).day())) – \(lastDay.formatted(.dateTime.day()))"

        return VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Daily spending", subtitle: isCurrentMonth ? "\(range) so far" : range)
            DailySpendingChart(
                daily: summary.daily,
                interval: summary.interval,
                average: summary.dailyAverage,
                currency: currency
            )
        }
        .card()
    }

    private var trendCard: some View {
        let totals = MonthlyTrend.totals(for: expenses, monthsEndingAt: month, count: 6)
        let average = totals.isEmpty ? 0 : totals.reduce(0) { $0 + $1.total } / Decimal(totals.count)

        return VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Last 6 months",
                       subtitle: "Average \(average.formattedCurrency(currency, fractionDigits: 0)) a month") {
                NavigationLink {
                    TrendsView(endMonth: month)
                } label: {
                    Text("See all")
                }
            }
            MonthlyTrendChart(
                totals: totals,
                currency: currency,
                highlightedMonth: month,
                style: .compact,
                height: 150
            )
        }
        .card()
    }

    private func recentCard(_ summary: MonthSummary) -> some View {
        let recent = Array(summary.expenses.prefix(5))

        return VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Recent") {
                NavigationLink {
                    ExpenseListView(
                        title: month.formatted(.dateTime.month(.wide).year()),
                        filter: .month(month)
                    )
                } label: {
                    Text("See all")
                }
            }
            ForEach(recent) { expense in
                Button {
                    editorRoute = .edit(expense)
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

    private var addButton: some View {
        Button {
            editorRoute = .new
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.brandFill, in: Circle())
                .addButtonShadow()
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

#if DEBUG
private struct OverviewPreview: View {
    var variant: PreviewVariant
    var budget: Double = 0
    var month: Date = .now
    var container: ModelContainer?

    var body: some View {
        DashboardView(month: month)
            .modelContainer(container ?? PreviewData.container)
            .defaultAppStorage(PreviewData.settings(monthlyBudget: budget))
            .previewVariant(variant)
    }
}

private extension Date {
    /// Sample data covers about 90 days, so this month has no expenses.
    static var emptyPreviewMonth: Date {
        Calendar.current.date(byAdding: .month, value: -5, to: .now) ?? .now
    }
}

#Preview("Within budget · Light") { OverviewPreview(variant: .light, budget: 100_000) }
#Preview("Within budget · Dark") { OverviewPreview(variant: .dark, budget: 100_000) }
#Preview("Within budget · Accessibility 3") { OverviewPreview(variant: .accessibility, budget: 100_000) }

#Preview("Over budget · Light") { OverviewPreview(variant: .light, budget: 20) }
#Preview("Over budget · Dark") { OverviewPreview(variant: .dark, budget: 20) }
#Preview("Over budget · Accessibility 3") { OverviewPreview(variant: .accessibility, budget: 20) }

#Preview("No budget · Light") { OverviewPreview(variant: .light) }
#Preview("No budget · Dark") { OverviewPreview(variant: .dark) }
#Preview("No budget · Accessibility 3") { OverviewPreview(variant: .accessibility) }

#Preview("Empty month · Light") { OverviewPreview(variant: .light, budget: 100_000, month: .emptyPreviewMonth) }
#Preview("Empty month · Dark") { OverviewPreview(variant: .dark, budget: 100_000, month: .emptyPreviewMonth) }
#Preview("Empty month · Accessibility 3") { OverviewPreview(variant: .accessibility, budget: 100_000, month: .emptyPreviewMonth) }

#Preview("No expenses · Light") { OverviewPreview(variant: .light, container: PreviewData.emptyContainer) }
#Preview("No expenses · Dark") { OverviewPreview(variant: .dark, container: PreviewData.emptyContainer) }
#Preview("No expenses · Accessibility 3") { OverviewPreview(variant: .accessibility, container: PreviewData.emptyContainer) }
#endif
