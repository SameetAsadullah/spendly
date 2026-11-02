import Foundation
import SwiftData

@Model
final class Expense {
    var title: String = ""
    var amount: Decimal = 0
    var date: Date = Date.now
    var notes: String = ""
    // Enums are stored as raw strings so they stay safe in predicates and migrations.
    var paymentMethodRaw: String = "card"
    var tags: [String] = []
    var recurrenceRaw: String = "never"
    var createdAt: Date = Date.now
    var category: ExpenseCategory?

    init(
        title: String = "",
        amount: Decimal = 0,
        date: Date = .now,
        notes: String = "",
        paymentMethod: PaymentMethod = .card,
        tags: [String] = [],
        recurrence: Recurrence = .never
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.notes = notes
        self.paymentMethodRaw = paymentMethod.rawValue
        self.tags = tags
        self.recurrenceRaw = recurrence.rawValue
        self.createdAt = .now
    }
}

extension Expense {
    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .other }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? .never }
        set { recurrenceRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (category?.name ?? "Expense") : trimmed
    }

    func matches(_ query: String) -> Bool {
        let fields = [
            title,
            notes,
            category?.name ?? "Uncategorized",
            tags.joined(separator: " "),
            paymentMethod.title,
            AmountParser.string(from: amount),
        ]
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Returns an unsaved copy. Set relationships only after inserting it into a context.
    func makeCopy(on date: Date, recurrence: Recurrence = .never) -> Expense {
        Expense(
            title: title,
            amount: amount,
            date: date,
            notes: notes,
            paymentMethod: paymentMethod,
            tags: tags,
            recurrence: recurrence
        )
    }
}
