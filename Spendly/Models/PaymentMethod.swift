import Foundation

enum PaymentMethod: String, CaseIterable, Identifiable, Codable {
    case card
    case debit
    case cash
    case bankTransfer
    case mobile
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: "Credit Card"
        case .debit: "Debit Card"
        case .cash: "Cash"
        case .bankTransfer: "Bank Transfer"
        case .mobile: "Mobile Pay"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .card: "creditcard.fill"
        case .debit: "creditcard"
        case .cash: "banknote.fill"
        case .bankTransfer: "building.columns.fill"
        case .mobile: "iphone"
        case .other: "ellipsis.circle.fill"
        }
    }
}
