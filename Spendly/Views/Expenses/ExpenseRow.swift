import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let currency: String
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: expense.category, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(expense.category?.name ?? "Uncategorized")
                    Text("·")
                    Image(systemName: expense.paymentMethod.icon)
                    if expense.recurrence != .never {
                        Image(systemName: "repeat")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !expense.tags.isEmpty {
                    Text(expense.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount.formattedCurrency(currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                Text(showsDate
                     ? expense.date.formatted(.dateTime.month(.abbreviated).day())
                     : expense.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
