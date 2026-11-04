import SwiftUI

enum AppSettings {
    static let currencyKey = "currencyCode"
    static let monthlyBudgetKey = "monthlyBudget"
    static let appearanceKey = "appearance"
    static let didSeedKey = "didSeedDefaultCategories"
    static let appLockKey = "appLockEnabled"
    static let hidesHeroAmountsKey = "hidesHeroAmounts"

    static var defaultCurrency: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static func currencySymbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    static func currencyName(for code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
