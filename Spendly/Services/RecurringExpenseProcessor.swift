import Foundation
import SwiftData

/// The latest occurrence of a recurring expense carries the recurrence rule.
/// When its next date has passed, a new occurrence takes over the rule and the old one becomes a plain expense.
enum RecurringExpenseProcessor {
    private static let maxOccurrencesPerRun = 400

    static func process(in context: ModelContext, now: Date = .now) {
        let never = Recurrence.never.rawValue
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate<Expense> { $0.recurrenceRaw != never })
        guard let recurring = try? context.fetch(descriptor), !recurring.isEmpty else { return }

        var created = 0
        for template in recurring {
            var current = template
            while created < maxOccurrencesPerRun,
                  let next = current.recurrence.nextDate(after: current.date),
                  next <= now {
                let occurrence = current.makeCopy(on: next, recurrence: current.recurrence)
                context.insert(occurrence)
                occurrence.category = current.category
                current.recurrence = .never
                current = occurrence
                created += 1
            }
        }
        if created > 0 {
            try? context.save()
        }
    }
}
