import SwiftData
import SwiftUI

struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @Binding var filter: ExpenseFilter
    let categories: [ExpenseCategory]
    let availableTags: [String]
    @State private var draft: ExpenseFilter

    init(filter: Binding<ExpenseFilter>, categories: [ExpenseCategory], availableTags: [String]) {
        _filter = filter
        self.categories = categories
        self.availableTags = availableTags
        _draft = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort") {
                    Picker(selection: $draft.sort) {
                        ForEach(SortOption.allCases) { option in
                            Label(option.title, systemImage: option.icon).tag(option)
                        }
                    } label: {
                        Label("Sort by", systemImage: "arrow.up.arrow.down")
                    }
                }

                Section("Date") {
                    Picker(selection: $draft.datePreset) {
                        ForEach(DatePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    } label: {
                        Label("Period", systemImage: "calendar")
                    }
                    if draft.datePreset == .custom {
                        DatePicker("From", selection: $draft.customStart, displayedComponents: .date)
                        DatePicker("To", selection: $draft.customEnd, in: draft.customStart..., displayedComponents: .date)
                    }
                }

                categorySection

                Section {
                    HStack {
                        Text("Minimum")
                        Spacer()
                        AmountField(placeholder: "Any", value: $draft.minAmount)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    HStack {
                        Text("Maximum")
                        Spacer()
                        AmountField(placeholder: "Any", value: $draft.maxAmount)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                } header: {
                    Text("Amount (\(AppSettings.currencySymbol(for: currency)))")
                } footer: {
                    if let min = draft.minAmount, let max = draft.maxAmount, min > max {
                        Text("Minimum is greater than maximum, so nothing will match.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Payment Method") {
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
                }

                if !availableTags.isEmpty {
                    Section {
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
                    } header: {
                        Text("Tags")
                    } footer: {
                        Text("Shows expenses with any of the selected tags.")
                    }
                }

                Section {
                    Toggle(isOn: $draft.recurringOnly) {
                        Label("Recurring only", systemImage: "repeat")
                    }
                }
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
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var categorySection: some View {
        Section {
            ForEach(categories) { category in
                let isOn = draft.categoryIDs.contains(category.persistentModelID)
                Button {
                    draft.categoryIDs.toggle(category.persistentModelID)
                } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(category: category, size: 30)
                        Text(category.name).foregroundStyle(Color.primary)
                        Spacer()
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn ? category.color : Color.secondary)
                            .font(.title3)
                    }
                }
            }
            Button {
                draft.includeUncategorized.toggle()
            } label: {
                HStack(spacing: 12) {
                    CategoryIcon(category: nil, size: 30)
                    Text("Uncategorized").foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: draft.includeUncategorized ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(draft.includeUncategorized ? Color.accentColor : Color.secondary)
                        .font(.title3)
                }
            }
        } header: {
            HStack {
                Text("Categories")
                Spacer()
                if !draft.categoryIDs.isEmpty || draft.includeUncategorized {
                    Button("Clear") {
                        draft.categoryIDs.removeAll()
                        draft.includeUncategorized = false
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                } else {
                    Button("Select All") {
                        draft.categoryIDs = Set(categories.map(\.persistentModelID))
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                    .disabled(categories.isEmpty)
                }
            }
        } footer: {
            Text("No selection shows all categories.")
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
