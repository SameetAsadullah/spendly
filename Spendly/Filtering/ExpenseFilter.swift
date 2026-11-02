import Foundation
import SwiftData

enum DatePreset: String, CaseIterable, Identifiable {
    case allTime
    case today
    case thisWeek
    case thisMonth
    case lastMonth
    case last30Days
    case last3Months
    case thisYear
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allTime: "All Time"
        case .today: "Today"
        case .thisWeek: "This Week"
        case .thisMonth: "This Month"
        case .lastMonth: "Last Month"
        case .last30Days: "Last 30 Days"
        case .last3Months: "Last 3 Months"
        case .thisYear: "This Year"
        case .custom: "Custom Range"
        }
    }

    func interval(customStart: Date, customEnd: Date, now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        switch self {
        case .allTime:
            return nil
        case .today:
            return DateInterval(start: today, end: tomorrow)
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: previous)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return DateInterval(start: start, end: tomorrow)
        case .last3Months:
            let thisMonth = calendar.monthInterval(for: now)
            let start = calendar.date(byAdding: .month, value: -2, to: thisMonth.start) ?? thisMonth.start
            return DateInterval(start: start, end: thisMonth.end)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        case .custom:
            let start = calendar.startOfDay(for: min(customStart, customEnd))
            let lastDay = calendar.startOfDay(for: max(customStart, customEnd))
            let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return DateInterval(start: start, end: end)
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case highest
    case lowest
    case alphabetical
    case category

    enum Grouping { case day, category, flat }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .highest: "Highest Amount"
        case .lowest: "Lowest Amount"
        case .alphabetical: "Title (A–Z)"
        case .category: "Category"
        }
    }

    var icon: String {
        switch self {
        case .newest: "calendar.badge.clock"
        case .oldest: "calendar"
        case .highest: "arrow.down.circle"
        case .lowest: "arrow.up.circle"
        case .alphabetical: "textformat"
        case .category: "square.grid.2x2"
        }
    }

    var grouping: Grouping {
        switch self {
        case .newest, .oldest: .day
        case .category: .category
        case .highest, .lowest, .alphabetical: .flat
        }
    }

    func sorted(_ items: [Expense]) -> [Expense] {
        switch self {
        case .newest:
            return items.sorted { $0.date > $1.date }
        case .oldest:
            return items.sorted { $0.date < $1.date }
        case .highest:
            return items.sorted { $0.amount > $1.amount }
        case .lowest:
            return items.sorted { $0.amount < $1.amount }
        case .alphabetical:
            return items.sorted {
                $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
        case .category:
            return items.sorted { lhs, rhs in
                let left = lhs.category?.name ?? "\u{FFFF}"
                let right = rhs.category?.name ?? "\u{FFFF}"
                if left != right {
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
                return lhs.date > rhs.date
            }
        }
    }
}

struct ExpenseFilter: Equatable {
    var searchText = ""
    var datePreset: DatePreset = .allTime
    var customStart: Date = Calendar.current.startOfMonth(for: .now)
    var customEnd: Date = .now
    var categoryIDs: Set<PersistentIdentifier> = []
    var includeUncategorized = false
    var paymentMethods: Set<PaymentMethod> = []
    var minAmount: Double?
    var maxAmount: Double?
    var tags: Set<String> = []
    var recurringOnly = false
    var sort: SortOption = .newest

    /// Number of active filter dimensions (search and sort excluded).
    var activeCount: Int {
        var count = 0
        if datePreset != .allTime { count += 1 }
        if !categoryIDs.isEmpty || includeUncategorized { count += 1 }
        if !paymentMethods.isEmpty { count += 1 }
        if minAmount != nil || maxAmount != nil { count += 1 }
        if !tags.isEmpty { count += 1 }
        if recurringOnly { count += 1 }
        return count
    }

    var isActive: Bool { activeCount > 0 }

    /// Clears every filter but keeps the search text and sort order.
    mutating func clearFilters() {
        var fresh = ExpenseFilter()
        fresh.searchText = searchText
        fresh.sort = sort
        self = fresh
    }

    var dateLabel: String {
        guard datePreset == .custom,
              let interval = datePreset.interval(customStart: customStart, customEnd: customEnd)
        else { return datePreset.title }
        let lastDay = interval.end.addingTimeInterval(-1)
        let sameYear = Calendar.current.isDate(interval.start, equalTo: .now, toGranularity: .year)
            && Calendar.current.isDate(lastDay, equalTo: .now, toGranularity: .year)
        let style: Date.FormatStyle = sameYear
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.month(.abbreviated).day().year()
        return "\(interval.start.formatted(style)) – \(lastDay.formatted(style))"
    }

    func amountLabel(currency: String) -> String? {
        switch (minAmount, maxAmount) {
        case let (min?, max?):
            return "\(min.formattedCurrency(currency, fractionDigits: 0)) – \(max.formattedCurrency(currency, fractionDigits: 0))"
        case let (min?, nil):
            return "≥ \(min.formattedCurrency(currency, fractionDigits: 0))"
        case let (nil, max?):
            return "≤ \(max.formattedCurrency(currency, fractionDigits: 0))"
        case (nil, nil):
            return nil
        }
    }

    func apply(to expenses: [Expense], now: Date = .now) -> [Expense] {
        let interval = datePreset.interval(customStart: customStart, customEnd: customEnd, now: now)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtersCategory = !categoryIDs.isEmpty || includeUncategorized

        let filtered = expenses.filter { expense in
            if let interval, !interval.containsHalfOpen(expense.date) { return false }
            if filtersCategory {
                if let category = expense.category {
                    if !categoryIDs.contains(category.persistentModelID) { return false }
                } else if !includeUncategorized {
                    return false
                }
            }
            if !paymentMethods.isEmpty, !paymentMethods.contains(expense.paymentMethod) { return false }
            if let minAmount, expense.amount < minAmount { return false }
            if let maxAmount, expense.amount > maxAmount { return false }
            if !tags.isEmpty, tags.isDisjoint(with: expense.tags) { return false }
            if recurringOnly, expense.recurrence == .never { return false }
            if !query.isEmpty, !expense.matches(query) { return false }
            return true
        }
        return sort.sorted(filtered)
    }
}

extension ExpenseFilter {
    static func category(_ category: ExpenseCategory?) -> ExpenseFilter {
        var filter = ExpenseFilter()
        if let category {
            filter.categoryIDs = [category.persistentModelID]
        } else {
            filter.includeUncategorized = true
        }
        return filter
    }

    static func month(_ date: Date, calendar: Calendar = .current) -> ExpenseFilter {
        var filter = ExpenseFilter()
        filter.restrict(toMonthOf: date, calendar: calendar)
        return filter
    }

    mutating func restrict(toMonthOf date: Date, calendar: Calendar = .current) {
        let interval = calendar.monthInterval(for: date)
        datePreset = .custom
        customStart = interval.start
        customEnd = interval.end.addingTimeInterval(-1)
    }
}
