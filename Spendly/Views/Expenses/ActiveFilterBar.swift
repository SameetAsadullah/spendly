import SwiftData
import SwiftUI

struct ActiveFilterBar: View {
    @Binding var filter: ExpenseFilter
    let categories: [ExpenseCategory]
    let currency: String

    private var selectedCategories: [ExpenseCategory] {
        categories.filter { filter.categoryIDs.contains($0.persistentModelID) }
    }

    private var selectedMethods: [PaymentMethod] {
        PaymentMethod.allCases.filter { filter.paymentMethods.contains($0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if filter.datePreset != .allTime {
                    RemovableChip(text: filter.dateLabel, icon: "calendar") {
                        filter.datePreset = .allTime
                    }
                }
                ForEach(selectedCategories) { category in
                    RemovableChip(text: category.name, icon: category.iconName, tint: category.color) {
                        filter.categoryIDs.remove(category.persistentModelID)
                    }
                }
                if filter.includeUncategorized {
                    RemovableChip(text: "Uncategorized", icon: "questionmark", tint: .gray) {
                        filter.includeUncategorized = false
                    }
                }
                ForEach(selectedMethods) { method in
                    RemovableChip(text: method.title, icon: method.icon, tint: .teal) {
                        filter.paymentMethods.remove(method)
                    }
                }
                if let label = filter.amountLabel(currency: currency) {
                    RemovableChip(text: label, icon: "dollarsign.circle", tint: .green) {
                        filter.minAmount = nil
                        filter.maxAmount = nil
                    }
                }
                ForEach(filter.tags.sorted(), id: \.self) { tag in
                    RemovableChip(text: "#\(tag)", tint: .pink) {
                        filter.tags.remove(tag)
                    }
                }
                if filter.recurringOnly {
                    RemovableChip(text: "Recurring", icon: "repeat", tint: .orange) {
                        filter.recurringOnly = false
                    }
                }
                Button("Clear all") {
                    filter.clearFilters()
                }
                .font(.footnote.weight(.semibold))
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}
