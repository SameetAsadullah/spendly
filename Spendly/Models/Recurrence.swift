import Foundation

enum Recurrence: String, CaseIterable, Identifiable, Codable {
    case never
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Every day"
        case .weekly: "Every week"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .never: nil
        case .daily: calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly: calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly: calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
