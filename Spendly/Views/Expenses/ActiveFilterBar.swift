import SwiftData
import SwiftUI

/// Removable chips for every active filter, with a "Clear all" link at the end.
struct ActiveFilterBar: View {
    @Binding var filter: ExpenseFilter
    let categories: [ExpenseCategory]
    let currency: String

    private var categoryChips: [CategoryFilterChip] {
        filter.categoryChips(in: categories)
    }

    private var selectedMethods: [PaymentMethod] {
        PaymentMethod.allCases.filter { filter.paymentMethods.contains($0) }
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            if filter.datePreset != .allTime {
                RemovableChip(text: filter.dateLabel, icon: "calendar") {
                    filter.datePreset = .allTime
                }
            }
            ForEach(categoryChips) { chip in
                RemovableChip(text: chip.label, icon: chip.iconName, tint: chip.category.color) {
                    filter.remove(chip)
                }
            }
            if filter.includeUncategorized {
                RemovableChip(text: "Uncategorized", icon: "questionmark", tint: Theme.uncategorized) {
                    filter.includeUncategorized = false
                }
            }
            ForEach(selectedMethods) { method in
                RemovableChip(text: method.title, icon: method.icon) {
                    filter.paymentMethods.remove(method)
                }
            }
            if let label = filter.amountLabel(currency: currency) {
                RemovableChip(text: label, icon: "dollarsign.circle") {
                    filter.minAmount = nil
                    filter.maxAmount = nil
                }
            }
            ForEach(filter.tags.sorted(), id: \.self) { tag in
                RemovableChip(text: "#\(tag)") {
                    filter.tags.remove(tag)
                }
            }
            if filter.recurringOnly {
                RemovableChip(text: "Recurring", icon: "repeat") {
                    filter.recurringOnly = false
                }
            }
            Button("Clear all") {
                filter.clearFilters()
            }
            .font(.footnote.weight(.semibold))
            .padding(.leading, 4)
        }
    }
}
