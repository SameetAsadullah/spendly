import SwiftData
import SwiftUI

struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @Binding var filter: ExpenseFilter
    let categories: [ExpenseCategory]
    let availableTags: [String]
    @State private var draft: ExpenseFilter

    private var mainCategories: [ExpenseCategory] { categories.filter { !$0.isSubcategory } }

    private let presets: [DatePreset] = [
        .allTime, .today, .thisWeek, .thisMonth, .last30Days, .lastMonth, .last3Months, .thisYear, .custom,
    ]

    init(filter: Binding<ExpenseFilter>, categories: [ExpenseCategory], availableTags: [String]) {
        _filter = filter
        self.categories = categories
        self.availableTags = availableTags
        var initial = filter.wrappedValue
        initial.syncDates()
        initial.foldDirectSubcategories(in: categories)
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort") {
                    Picker("Sort by", selection: $draft.sort) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                dateSection
                categorySection
                amountSection
                paymentSection
                tagSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { draft.clearFilters() }
                        .disabled(!draft.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filter = draft
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var dateSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(presets) { preset in
                    Button {
                        draft.setPreset(preset)
                    } label: {
                        Chip(text: preset.title, isSelected: draft.datePreset == preset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            if draft.datePreset != .allTime {
                DatePicker("From", selection: dateBinding(\.customStart), displayedComponents: .date)
                DatePicker("To", selection: dateBinding(\.customEnd), displayedComponents: .date)
            }
        } header: {
            Text("Date")
        } footer: {
            Text("A preset fills both dates. Changing either date switches the preset to Custom.")
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<ExpenseFilter, Date>) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: {
                draft[keyPath: keyPath] = $0
                draft.datePreset = .custom
            }
        )
    }

    private var categorySection: some View {
        let hasSelection = !draft.categoryIDs.isEmpty || draft.includeUncategorized
        return Section {
            FlowLayout(spacing: 8) {
                ForEach(mainCategories) { category in
                    Button {
                        draft.toggle(category)
                    } label: {
                        Chip(
                            text: category.name,
                            icon: category.iconName,
                            iconTint: category.color,
                            isSelected: draft.categoryIDs.contains(category.persistentModelID)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    draft.includeUncategorized.toggle()
                } label: {
                    Chip(
                        text: "Uncategorized",
                        icon: "questionmark",
                        iconTint: Theme.uncategorized,
                        isSelected: draft.includeUncategorized
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            ForEach(mainCategories.filter { draft.categoryIDs.contains($0.persistentModelID) && $0.hasSubcategories }) { main in
                subcategoryRow(for: main)
            }
        } header: {
            HStack(spacing: 12) {
                Text("Categories")
                Spacer()
                if hasSelection {
                    Button("Clear") {
                        draft.categoryIDs.removeAll()
                        draft.subcategoryIDs.removeAll()
                        draft.includeUncategorized = false
                    }
                    .font(.footnote.weight(.semibold))
                    .textCase(nil)
                }
                Button("Select All") {
                    draft.categoryIDs = Set(mainCategories.map(\.persistentModelID))
                    draft.subcategoryIDs.removeAll()
                    draft.includeUncategorized = true
                }
                .font(.footnote.weight(.semibold))
                .textCase(nil)
            }
        } footer: {
            Text("No selection shows all categories.")
        }
    }

    private func subcategoryRow(for main: ExpenseCategory) -> some View {
        let kept = draft.subcategoryIDs[main.persistentModelID] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(main.name) subcategories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                Button {
                    draft.subcategoryIDs[main.persistentModelID] = nil
                } label: {
                    Chip(text: "All", isSelected: kept.isEmpty)
                }
                .buttonStyle(.plain)
                ForEach(main.sortedSubcategories) { sub in
                    Button {
                        draft.toggleSubcategory(sub, of: main)
                    } label: {
                        Chip(
                            text: sub.name,
                            icon: sub.iconName,
                            iconTint: sub.color,
                            isSelected: kept.contains(sub.persistentModelID)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    draft.toggleSubcategory(nil, of: main)
                } label: {
                    Chip(text: "No subcategory", isSelected: kept.contains(main.persistentModelID))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var amountSection: some View {
        Section {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                amountField("Minimum", value: $draft.minAmount)
                amountField("Maximum", value: $draft.maxAmount)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Amount (\(AppSettings.currencySymbol(for: currency)))")
        } footer: {
            if let min = draft.minAmount, let max = draft.maxAmount, min > max {
                Text("Minimum is greater than maximum, so nothing will match.")
                    .foregroundStyle(.red)
            }
        }
    }

    private func amountField(_ label: String, value: Binding<Decimal?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            AmountField(placeholder: "No limit", value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paymentSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        draft.paymentMethods.toggle(method)
                    } label: {
                        Chip(text: method.title, icon: method.icon,
                             isSelected: draft.paymentMethods.contains(method))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Payment Method")
        } footer: {
            Text("None selected includes every method.")
        }
    }

    private var tagSection: some View {
        Section {
            if !availableTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        Button {
                            draft.tags.toggle(tag)
                        } label: {
                            Chip(text: "#\(tag)", isSelected: draft.tags.contains(tag))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Toggle(isOn: $draft.recurringOnly) {
                Label("Recurring only", systemImage: "repeat")
            }
        } header: {
            Text("Tags")
        } footer: {
            if !availableTags.isEmpty {
                Text("Shows expenses with any of the selected tags.")
            }
        }
    }
}

extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

#if DEBUG
private struct FilterSheetPreview: View {
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var filter: ExpenseFilter = {
        var filter = ExpenseFilter()
        filter.datePreset = .thisMonth
        filter.paymentMethods = [.card]
        return filter
    }()

    var body: some View {
        ExpenseFilterSheet(filter: $filter, categories: categories, availableTags: ["coffee", "work", "trip"])
    }
}

private struct SubcategoryFilterSheetPreview: View {
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    var body: some View {
        if let food = categories.first(where: { $0.name == "Food & Dining" && !$0.isSubcategory }),
           let outside = food.sortedSubcategories.first(where: { $0.name == "Outside" }) {
            var filter = ExpenseFilter()
            let _ = filter.categoryIDs = [food.persistentModelID]
            let _ = filter.subcategoryIDs[food.persistentModelID] = [outside.persistentModelID]
            ExpenseFilterSheet(filter: .constant(filter), categories: categories, availableTags: [])
        }
    }
}

#Preview("Filter light") {
    FilterSheetPreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Filter dark") {
    FilterSheetPreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Filter accessibility3") {
    FilterSheetPreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}

#Preview("Subcategory filter light") {
    SubcategoryFilterSheetPreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Subcategory filter dark") {
    SubcategoryFilterSheetPreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}
#endif
