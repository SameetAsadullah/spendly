import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let currency: String
    /// For lists that span several days: shows "Yesterday" or the date instead of the time.
    var showsDay = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize

        HStack(alignment: isLarge ? .top : .center, spacing: 12) {
            CategoryIcon(category: expense.category, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(isLarge ? 3 : 1)

                HStack(spacing: 4) {
                    Text(expense.category?.path ?? "Uncategorized")
                    Image(systemName: expense.paymentMethod.icon)
                        .accessibilityLabel(expense.paymentMethod.title)
                    if expense.recurrence != .never {
                        Image(systemName: "repeat")
                            .accessibilityLabel("Repeats \(expense.recurrence.title.lowercased())")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isLarge ? 2 : 1)

                if !expense.tags.isEmpty {
                    Text(expense.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                        .lineLimit(isLarge ? 2 : 1)
                }

                if isLarge {
                    amountAndDate(alignment: .leading)
                        .padding(.top, 3)
                }
            }

            if !isLarge {
                Spacer(minLength: 8)
                amountAndDate(alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func amountAndDate(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(expense.amount.formattedCurrency(currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
            Text(dateText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateText: String {
        let calendar = Calendar.current
        let date = expense.date
        if !showsDay || calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
