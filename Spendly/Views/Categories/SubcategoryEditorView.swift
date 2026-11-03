import SwiftData
import SwiftUI

/// The New and Edit Subcategory sheet.
struct SubcategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    /// nil creates a new subcategory.
    let subcategory: ExpenseCategory?
    /// The preset parent for a new subcategory.
    let parent: ExpenseCategory?
    var onSave: ((ExpenseCategory) -> Void)?

    @State private var parentID: PersistentIdentifier?
    @State private var name: String
    @State private var iconName: String
    @State private var budget: Decimal?
    @State private var showDeleteConfirmation = false

    init(subcategory: ExpenseCategory? = nil, parent: ExpenseCategory? = nil, onSave: ((ExpenseCategory) -> Void)? = nil) {
        self.subcategory = subcategory
        self.parent = parent ?? subcategory?.parent
        self.onSave = onSave
        _parentID = State(initialValue: (parent ?? subcategory?.parent)?.persistentModelID)
        _name = State(initialValue: subcategory?.name ?? "")
        _iconName = State(initialValue: subcategory?.iconName ?? "tag.fill")
        _budget = State(initialValue: (subcategory?.monthlyBudget ?? 0) > 0 ? subcategory?.monthlyBudget : nil)
    }

    private var mainCategories: [ExpenseCategory] { categories.filter { !$0.isSubcategory } }

    private var selectedParent: ExpenseCategory? {
        mainCategories.first { $0.persistentModelID == parentID }
    }

    private var tint: Color { selectedParent?.color ?? Theme.uncategorized }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        (selectedParent?.subcategories ?? []).contains { other in
            other.persistentModelID != subcategory?.persistentModelID
                && other.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var canSave: Bool { selectedParent != nil && !trimmedName.isEmpty && !isDuplicateName }

    private var previewPath: String {
        let label = trimmedName.isEmpty ? "New Subcategory" : trimmedName
        guard let selectedParent else { return label }
        return "\(selectedParent.name) › \(label)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        CategoryIcon(iconName: iconName, color: tint, size: 84)
                            .animation(.snappy, value: iconName)
                            .animation(.snappy, value: parentID)
                        Text(previewPath)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    Picker("Parent Category", selection: $parentID) {
                        if parentID == nil {
                            Text("Select").tag(PersistentIdentifier?.none)
                        }
                        ForEach(mainCategories) { category in
                            Label(category.name, systemImage: category.iconName)
                                .tag(Optional(category.persistentModelID))
                        }
                    }
                }

                Section {
                    TextField("Name (e.g. Coffee)", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    if isDuplicateName {
                        Text("This category already has a subcategory with this name.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    LabeledContent {
                        Text("Same as parent")
                    } label: {
                        Label("Color", systemImage: "lock.fill")
                    }
                    .foregroundStyle(.secondary)
                }

                Section("Icon") {
                    CategoryIconGrid(selection: $iconName, tint: tint)
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
                    Text("Optional. It also counts toward the parent's budget.")
                }

                if subcategory != nil {
                    Section {
                        Button("Delete Subcategory", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(subcategory == nil ? "New Subcategory" : "Edit Subcategory")
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
            .confirmationDialog(
                "Delete “\(subcategory?.name ?? "subcategory")”?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Subcategory", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) {}
            } message: {
                let count = subcategory?.expenseCount ?? 0
                if count > 0, let parent = subcategory?.parent {
                    Text("\(count) \(count == 1 ? "expense moves" : "expenses move") to \(parent.name).")
                } else {
                    Text("This subcategory has no expenses.")
                }
            }
        }
    }

    private func save() {
        guard canSave, let selectedParent else { return }
        let target: ExpenseCategory
        if let subcategory {
            target = subcategory
        } else {
            let nextOrder = ((selectedParent.subcategories ?? []).map(\.sortOrder).max() ?? -1) + 1
            target = ExpenseCategory(name: trimmedName, iconName: iconName, colorHex: selectedParent.colorHex, sortOrder: nextOrder)
            context.insert(target)
        }
        target.name = trimmedName
        target.iconName = iconName
        target.parent = selectedParent
        target.colorHex = selectedParent.colorHex
        target.monthlyBudget = max(budget ?? 0, 0)
        try? context.save()
        onSave?(target)
        dismiss()
    }

    private func delete() {
        guard let subcategory else { return }
        subcategory.delete(includingExpenses: false, in: context)
        try? context.save()
        dismiss()
    }
}

#if DEBUG
@MainActor private struct SubcategoryEditorPreview: View {
    var isEditing: Bool

    var body: some View {
        let categories = (try? PreviewData.container.mainContext
            .fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let main = categories.first { $0.hasSubcategories }
        SubcategoryEditorView(
            subcategory: isEditing ? main?.sortedSubcategories.first : nil,
            parent: isEditing ? nil : main
        )
    }
}

#Preview("New, light") {
    SubcategoryEditorPreview(isEditing: false).modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("New, dark") {
    SubcategoryEditorPreview(isEditing: false).modelContainer(PreviewData.container).previewVariant(.dark)
}

#Preview("Edit, light") {
    SubcategoryEditorPreview(isEditing: true).modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("Edit, dark") {
    SubcategoryEditorPreview(isEditing: true).modelContainer(PreviewData.container).previewVariant(.dark)
}
#endif
