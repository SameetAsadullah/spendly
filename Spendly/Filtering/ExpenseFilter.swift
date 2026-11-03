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
        case .custom: "Custom"
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
        case .alphabetical: "Title A–Z"
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
                let left = lhs.category?.path ?? "\u{FFFF}"
                let right = rhs.category?.path ?? "\u{FFFF}"
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
    /// A main category here includes its subcategories, unless `subcategoryIDs` narrows it.
    var categoryIDs: Set<PersistentIdentifier> = []
    /// For a main category in `categoryIDs`, the subcategories to keep. The main category's own ID
    /// stands for "No subcategory". No entry, or an empty set, means all of them.
    var subcategoryIDs: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
    var includeUncategorized = false
    var paymentMethods: Set<PaymentMethod> = []
    var minAmount: Decimal?
    var maxAmount: Decimal?
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

    /// Sets the preset and, for a dated preset, fills the From and To dates from its interval.
    mutating func setPreset(_ preset: DatePreset, now: Date = .now, calendar: Calendar = .current) {
        datePreset = preset
        syncDates(now: now, calendar: calendar)
    }

    /// Fills customStart and customEnd from the preset. The interval is half-open, so the last day is end minus 1 second.
    mutating func syncDates(now: Date = .now, calendar: Calendar = .current) {
        guard datePreset != .custom,
              let interval = datePreset.interval(customStart: customStart, customEnd: customEnd, now: now, calendar: calendar)
        else { return }
        customStart = interval.start
        customEnd = interval.end.addingTimeInterval(-1)
    }

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
                    if !includes(category) { return false }
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

    func includes(_ category: ExpenseCategory) -> Bool {
        let id = category.persistentModelID
        if category.isSubcategory, categoryIDs.contains(id) { return true }
        let mainID = category.mainCategory.persistentModelID
        guard categoryIDs.contains(mainID) else { return false }
        guard let kept = subcategoryIDs[mainID], !kept.isEmpty else { return true }
        return kept.contains(id)
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

/// One removable category entry in the active filter bar.
struct CategoryFilterChip: Identifiable {
    enum Scope {
        case whole
        case subcategory(ExpenseCategory)
        case noSubcategory
    }

    let category: ExpenseCategory
    let scope: Scope

    var id: String {
        switch scope {
        case .whole: "whole-\(category.persistentModelID.hashValue)"
        case .subcategory(let sub): "sub-\(sub.persistentModelID.hashValue)"
        case .noSubcategory: "none-\(category.persistentModelID.hashValue)"
        }
    }

    var label: String {
        switch scope {
        case .whole: category.path
        case .subcategory(let sub): sub.path
        case .noSubcategory: "\(category.name) › No subcategory"
        }
    }

    var iconName: String {
        if case .subcategory(let sub) = scope { return sub.iconName }
        return category.iconName
    }
}

extension ExpenseFilter {
    /// The one category or subcategory the filter is narrowed to, or nil when it holds several
    /// or the main category is narrowed to "No subcategory" or to more than one subcategory.
    var singleCategoryID: PersistentIdentifier? {
        guard categoryIDs.count == 1, let id = categoryIDs.first else { return nil }
        guard let kept = subcategoryIDs[id], !kept.isEmpty else { return id }
        guard kept.count == 1, let only = kept.first, only != id else { return nil }
        return only
    }

    func categoryChips(in categories: [ExpenseCategory]) -> [CategoryFilterChip] {
        var chips: [CategoryFilterChip] = []
        for category in categories where categoryIDs.contains(category.persistentModelID) {
            if category.isSubcategory {
                chips.append(CategoryFilterChip(category: category.mainCategory, scope: .subcategory(category)))
                continue
            }
            let kept = subcategoryIDs[category.persistentModelID] ?? []
            guard !kept.isEmpty else {
                chips.append(CategoryFilterChip(category: category, scope: .whole))
                continue
            }
            for sub in category.sortedSubcategories where kept.contains(sub.persistentModelID) {
                chips.append(CategoryFilterChip(category: category, scope: .subcategory(sub)))
            }
            if kept.contains(category.persistentModelID) {
                chips.append(CategoryFilterChip(category: category, scope: .noSubcategory))
            }
        }
        return chips
    }

    /// Removes the chip's selection. Removing the last narrowed subcategory removes the category.
    mutating func remove(_ chip: CategoryFilterChip) {
        let mainID = chip.category.persistentModelID
        switch chip.scope {
        case .whole:
            deselect(chip.category)
        case .subcategory(let sub):
            if categoryIDs.contains(sub.persistentModelID) {
                categoryIDs.remove(sub.persistentModelID)
            } else {
                removeKept(sub.persistentModelID, of: mainID)
            }
        case .noSubcategory:
            removeKept(mainID, of: mainID)
        }
    }

    private mutating func removeKept(_ id: PersistentIdentifier, of mainID: PersistentIdentifier) {
        var kept = subcategoryIDs[mainID] ?? []
        kept.remove(id)
        if kept.isEmpty {
            categoryIDs.remove(mainID)
            subcategoryIDs[mainID] = nil
        } else {
            subcategoryIDs[mainID] = kept
        }
    }

    /// Selects or deselects a main category. Deselecting drops its subcategory narrowing.
    mutating func toggle(_ main: ExpenseCategory) {
        if categoryIDs.contains(main.persistentModelID) {
            deselect(main)
        } else {
            categoryIDs.insert(main.persistentModelID)
        }
    }

    mutating func deselect(_ main: ExpenseCategory) {
        categoryIDs.remove(main.persistentModelID)
        subcategoryIDs[main.persistentModelID] = nil
    }

    func isNarrowed(_ main: ExpenseCategory) -> Bool {
        !(subcategoryIDs[main.persistentModelID] ?? []).isEmpty
    }

    /// Toggles a subcategory, or "No subcategory" when `sub` is nil. Choosing every chip returns to all.
    mutating func toggleSubcategory(_ sub: ExpenseCategory?, of main: ExpenseCategory) {
        let mainID = main.persistentModelID
        var kept = subcategoryIDs[mainID] ?? []
        kept.toggle(sub?.persistentModelID ?? mainID)
        let everything = Set(main.sortedSubcategories.map(\.persistentModelID)).union([mainID])
        subcategoryIDs[mainID] = kept.isEmpty || kept == everything ? nil : kept
    }

    /// Rewrites a subcategory selected directly in `categoryIDs` as narrowing of its main category,
    /// which matches the same expenses and is what the filter sheet shows.
    mutating func foldDirectSubcategories(in categories: [ExpenseCategory]) {
        for sub in categories where sub.isSubcategory && categoryIDs.contains(sub.persistentModelID) {
            let mainID = sub.mainCategory.persistentModelID
            categoryIDs.remove(sub.persistentModelID)
            if !categoryIDs.contains(mainID) {
                categoryIDs.insert(mainID)
                subcategoryIDs[mainID, default: []].insert(sub.persistentModelID)
            } else if var kept = subcategoryIDs[mainID], !kept.isEmpty {
                kept.insert(sub.persistentModelID)
                subcategoryIDs[mainID] = kept
            }
        }
    }
}
