import SwiftData
import SwiftUI

struct CategorySlice: Identifiable {
    let id: PersistentIdentifier?
    let category: ExpenseCategory?
    let total: Decimal
    let count: Int

    var name: String { category?.name ?? "Uncategorized" }
    var iconName: String { category?.iconName ?? "questionmark" }
    var color: Color { category?.color ?? .gray }
}

struct DailyTotal: Identifiable {
    let day: Date
    let total: Decimal
    var id: Date { day }
}

struct MonthSummary {
    let interval: DateInterval
    let expenses: [Expense]
    let total: Decimal
    let previousTotal: Decimal
    let slices: [CategorySlice]
    let daily: [DailyTotal]
    let daysCounted: Int

    init(allExpenses: [Expense], month: Date, now: Date = .now, calendar: Calendar = .current) {
        let interval = calendar.monthInterval(for: month)
        let previousStart = calendar.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let previousInterval = calendar.monthInterval(for: previousStart)

        let inMonth = allExpenses.filter { interval.containsHalfOpen($0.date) }
        self.interval = interval
        self.expenses = inMonth.sorted { $0.date > $1.date }
        self.total = inMonth.reduce(0) { $0 + $1.amount }
        self.previousTotal = allExpenses
            .filter { previousInterval.containsHalfOpen($0.date) }
            .reduce(0) { $0 + $1.amount }

        let byCategory = Dictionary(grouping: inMonth) { $0.category?.persistentModelID }
        self.slices = byCategory
            .map { id, items in
                CategorySlice(
                    id: id,
                    category: items.first?.category,
                    total: items.reduce(0) { $0 + $1.amount },
                    count: items.count
                )
            }
            .sorted { $0.total > $1.total }

        let byDay = Dictionary(grouping: inMonth) { calendar.startOfDay(for: $0.date) }
        self.daily = byDay
            .map { DailyTotal(day: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }

        let daysInMonth = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        if interval.containsHalfOpen(now) {
            self.daysCounted = calendar.component(.day, from: now)
        } else if interval.start > now {
            self.daysCounted = 1
        } else {
            self.daysCounted = daysInMonth
        }
    }

    var count: Int { expenses.count }
    var dailyAverage: Decimal { total / Decimal(max(daysCounted, 1)) }
    var largest: Expense? { expenses.max { $0.amount < $1.amount } }

    /// Fractional change against the previous month; nil when there is nothing to compare.
    var changeRatio: Double? {
        previousTotal > 0 ? ((total - previousTotal) / previousTotal).doubleValue : nil
    }

    func spent(in category: ExpenseCategory) -> Decimal {
        slices.first { $0.id == category.persistentModelID }?.total ?? 0
    }
}

struct MonthTotal: Identifiable {
    let month: Date
    let total: Decimal
    let count: Int
    var id: Date { month }
}

enum MonthlyTrend {
    /// Oldest month first. Months without expenses are included with a zero total.
    static func totals(
        for expenses: [Expense],
        monthsEndingAt end: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [MonthTotal] {
        let lastMonth = calendar.startOfMonth(for: end)
        let byMonth = Dictionary(grouping: expenses) { calendar.startOfMonth(for: $0.date) }
        return (0..<count).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: lastMonth) else { return nil }
            let items = byMonth[month] ?? []
            return MonthTotal(month: month, total: items.reduce(0) { $0 + $1.amount }, count: items.count)
        }
    }
}
