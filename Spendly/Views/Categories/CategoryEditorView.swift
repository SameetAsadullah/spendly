import SwiftData
import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var existingCategories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    let category: ExpenseCategory?
    var onSave: ((ExpenseCategory) -> Void)?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var budget: Decimal?
    @State private var customColor: Color

    init(category: ExpenseCategory?, onSave: ((ExpenseCategory) -> Void)? = nil) {
        self.category = category
        self.onSave = onSave
        let hex = category?.colorHex ?? CategoryPalette.colors.randomElement() ?? "#4F46E5"
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: hex)
        _budget = State(initialValue: (category?.monthlyBudget ?? 0) > 0 ? category?.monthlyBudget : nil)
        _customColor = State(initialValue: Color(hex: hex))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        existingCategories.contains { other in
            other.persistentModelID != category?.persistentModelID
                && other.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var canSave: Bool { !trimmedName.isEmpty && !isDuplicateName }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        CategoryIcon(iconName: iconName, color: Color(hex: colorHex), size: 84)
                            .animation(.snappy, value: iconName)
                            .animation(.snappy, value: colorHex)
                        Text(trimmedName.isEmpty ? "New Category" : trimmedName)
                            .font(.title3.weight(.bold))
                        if let budget, budget > 0 {
                            Text("Budget \(budget.formattedCurrency(currency)) / month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField("Name (e.g. Coffee)", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    if isDuplicateName {
                        Text("A category with this name already exists.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 12) {
                        ForEach(CategoryPalette.colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                        }
                    }
                    .padding(.vertical, 6)
                    ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newValue in
                            if let hex = newValue.hexString { colorHex = hex }
                        }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(CategoryPalette.icons, id: \.self) { icon in
                            let isSelected = iconName == icon
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .background(
                                        isSelected ? Color(hex: colorHex) : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    HStack {
                        Text(AppSettings.currencySymbol(for: currency))
                            .foregroundStyle(.secondary)
                        AmountField(placeholder: "No budget", value: $budget)
                    }
                } header: {
                    Text("Monthly Budget")
                } footer: {
                    Text("Optional. Shows progress on the Overview and warns when you go over.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let target: ExpenseCategory
        if let category {
            target = category
        } else {
            let nextOrder = (existingCategories.map(\.sortOrder).max() ?? -1) + 1
            target = ExpenseCategory(name: trimmedName, iconName: iconName, colorHex: colorHex, sortOrder: nextOrder)
            context.insert(target)
        }
        target.name = trimmedName
        target.iconName = iconName
        target.colorHex = colorHex
        target.monthlyBudget = max(budget ?? 0, 0)
        try? context.save()
        onSave?(target)
        dismiss()
    }
}
