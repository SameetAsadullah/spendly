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
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(CategoryPalette.colors, id: \.self) { hex in
                            let isSelected = colorHex == hex
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .padding(5)
                                    .overlay {
                                        if isSelected {
                                            Circle().strokeBorder(Color(hex: hex), lineWidth: 2)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                    ColorPicker("Custom Color", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newValue in
                            if let hex = newValue.hexString { colorHex = hex }
                        }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(CategoryPalette.icons, id: \.self) { icon in
                            let isSelected = iconName == icon
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(isSelected ? Color(hex: colorHex) : Color.primary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(
                                        Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color(hex: colorHex), lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    Text("Optional. Leave empty for no budget bar.")
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

#if DEBUG
#Preview("New, light") {
    CategoryEditorView(category: nil).modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("New, dark") {
    CategoryEditorView(category: nil).modelContainer(PreviewData.container).previewVariant(.dark)
}

#Preview("New, accessibility3") {
    CategoryEditorView(category: nil).modelContainer(PreviewData.container).previewVariant(.accessibility)
}

@MainActor private struct EditPreview: View {
    var body: some View {
        let category = try? PreviewData.container.mainContext
            .fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)])).first
        CategoryEditorView(category: category)
    }
}

#Preview("Edit, light") {
    EditPreview().modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("Edit, dark") {
    EditPreview().modelContainer(PreviewData.container).previewVariant(.dark)
}

#Preview("Edit, accessibility3") {
    EditPreview().modelContainer(PreviewData.container).previewVariant(.accessibility)
}
#endif
