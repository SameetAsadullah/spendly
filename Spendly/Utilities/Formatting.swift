import Foundation

extension Decimal {
    /// Goes through the shortest text form of the Double, so 12.34 stays 12.34 and does not become 12.3399….
    init(roundTripping value: Double) {
        self = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// For charts and progress ratios only. Keep money arithmetic in Decimal.
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    func formattedCurrency(_ code: String, fractionDigits: Int? = nil) -> String {
        if let fractionDigits {
            return formatted(.currency(code: code).precision(.fractionLength(fractionDigits)))
        }
        return formatted(.currency(code: code))
    }
}

/// Parses user-typed amounts in the current locale ("12,50" or "12.50").
enum AmountParser {
    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        formatter.generatesDecimalNumbers = true
        if let number = formatter.number(from: trimmed) as? NSDecimalNumber {
            return number.decimalValue
        }
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: "."),
                       locale: Locale(identifier: "en_US_POSIX"))
    }

    static func string(from value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? ""
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    func monthInterval(for date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 86_400)
    }
}

extension DateInterval {
    /// Half-open check: the end instant belongs to the next period.
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

enum DayTitle {
    static func string(for day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if calendar.isDate(day, equalTo: .now, toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }
}
