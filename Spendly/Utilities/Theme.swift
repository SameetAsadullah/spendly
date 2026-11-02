import SwiftUI
import UIKit

enum Theme {
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardCornerRadius: CGFloat = 22
}

enum CategoryPalette {
    static let colors: [String] = [
        "#FF6B6B", "#FF9F43", "#FECA57", "#1DD1A1",
        "#10AC84", "#48DBFB", "#2E86DE", "#4F46E5",
        "#7C3AED", "#A55EEA", "#FF6B9D", "#E17055",
        "#C8A165", "#00B894", "#576574", "#8395A7",
    ]

    static let icons: [String] = [
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "cart.fill",
        "bag.fill", "tshirt.fill", "gift.fill", "sparkles",
        "car.fill", "bus.fill", "fuelpump.fill", "airplane",
        "house.fill", "bolt.fill", "drop.fill", "wifi",
        "phone.fill", "tv.fill", "gamecontroller.fill", "film.fill",
        "music.note", "book.fill", "graduationcap.fill", "briefcase.fill",
        "heart.fill", "cross.case.fill", "pills.fill", "dumbbell.fill",
        "pawprint.fill", "leaf.fill", "figure.and.child.holdinghands", "scissors",
        "creditcard.fill", "banknote.fill", "building.columns.fill", "wrench.and.screwdriver.fill",
        "hammer.fill", "tag.fill", "star.fill", "ellipsis.circle.fill",
    ]
}

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func byte(_ component: CGFloat) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
            )
    }

    @MainActor
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
