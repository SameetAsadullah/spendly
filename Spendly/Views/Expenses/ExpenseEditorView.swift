import SwiftData
import SwiftUI

enum ExpenseEditorRoute: Identifiable {
    case new
    case edit(Expense)
    case duplicate(Expense)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let expense): "edit-\(expense.persistentModelID.hashValue)"
        case .duplicate(let expense): "duplicate-\(expense.persistentModelID.hashValue)"
        }
    }
}

struct ExpenseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @Query private var allExpenses: [Expense]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency

    let route: ExpenseEditorRoute
    let presetCategory: ExpenseCategory?

    @State private var amountText: String
    @State private var title: String
    @State private var date: Date
    @State private var category: ExpenseCategory?
    @State private var subcategory: ExpenseCategory?
    @State private var paymentMethod: PaymentMethod
    @State private var recurrence: Recurrence
    @State private var tags: [String]
    @State private var notes: String
    @State private var showNewCategory = false
    @State private var showNewSubcategory = false
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    init(route: ExpenseEditorRoute, presetCategory: ExpenseCategory? = nil) {
        self.route = route
        self.presetCategory = presetCategory

        let source: Expense?
        switch route {
        case .new: source = nil
        case .edit(let expense), .duplicate(let expense): source = expense
        }
        let isEdit: Bool
        if case .edit = route { isEdit = true } else { isEdit = false }

        _amountText = State(initialValue: source.map { AmountParser.string(from: $0.amount) } ?? "")
        _title = State(initialValue: source?.title ?? "")
        _date = State(initialValue: isEdit ? (source?.date ?? .now) : .now)
        let initial = source?.category ?? presetCategory
        _category = State(initialValue: initial?.mainCategory)
        _subcategory = State(initialValue: initial?.isSubcategory == true ? initial : nil)
        _paymentMethod = State(initialValue: source?.paymentMethod ?? .card)
        _recurrence = State(initialValue: isEdit ? (source?.recurrence ?? .never) : .never)
        _tags = State(initialValue: source?.tags ?? [])
        _notes = State(initialValue: source?.notes ?? "")
    }

    private var editingExpense: Expense? {
        if case .edit(let expense) = route { return expense }
        return nil
    }

    private var mainCategories: [ExpenseCategory] { categories.filter { !$0.isSubcategory } }

    private var amount: Decimal? { AmountParser.parse(amountText) }
    private var isValid: Bool { (amount ?? 0) > 0 }

    private var knownTags: [String] {
        Array(Set(allExpenses.flatMap(\.tags))).sorted()
    }

    private var navigationTitle: String {
        switch route {
        case .new: "New Expense"
        case .edit: "Edit Expense"
        case .duplicate: "Duplicate Expense"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                Section {
                    TextField("Title, e.g. Lunch with the team", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                categorySection
                detailsSection
                Section("Tags") {
                    TagEditor(tags: $tags, suggestions: knownTags)
                }
                Section("Notes") {
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                if editingExpense != nil {
                    Section {
                        Button("Delete Expense", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        amountFocused = false
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryEditorView(category: nil) { newCategory in
                    category = newCategory
                    subcategory = nil
                }
            }
            .sheet(isPresented: $showNewSubcategory) {
                SubcategoryEditorView(subcategory: nil, parent: category) { newSubcategory in
                    subcategory = newSubcategory
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteExpense)
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                if case .new = route, category == nil {
                    category = mainCategories.first
                }
            }
            .task {
                guard case .new = route else { return }
                try? await Task.sleep(for: .milliseconds(350))
                amountFocused = true
            }
        }
    }

    // MARK: Sections

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    private var amountSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(AppSettings.currencySymbol(for: currency))
                    .font(.editorCurrencySymbol)
                    .foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.editorAmount)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .fixedSize()
                    .accessibilityLabel("Amount")
                    .onChange(of: amountText) { _, newValue in
                        let cleaned = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                        if cleaned != newValue { amountText = cleaned }
                    }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }
        }
        .listRowBackground(Color.clear)
    }

    private var categorySection: some View {
        Section {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: isLargeText ? 3 : 5),
                spacing: 8
            ) {
                ForEach(mainCategories) { item in
                    CategoryChoice(category: item, isSelected: category == item) {
                        withAnimation(.snappy) {
                            if category != item { subcategory = nil }
                            category = item
                        }
                    }
                }
                Button { showNewCategory = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(
                                Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.icon(44), style: .continuous)
                            )
                            .padding(4)
                        Text("New")
                            .font(.caption2)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New category")
            }
            .padding(.vertical, 4)
            if let category, category.hasSubcategories {
                subcategoryPicker(for: category)
            }
        } header: {
            Text("Category")
        } footer: {
            if category == nil {
                Text("No category selected. This expense will be Uncategorized.")
            }
        }
    }

    private func subcategoryPicker(for main: ExpenseCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(main.name) subcategory")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                subcategoryChip("None", isSelected: subcategory == nil) { subcategory = nil }
                ForEach(main.sortedSubcategories) { item in
                    subcategoryChip(item.name, icon: item.iconName, isSelected: subcategory == item) {
                        subcategory = item
                    }
                }
                Button { showNewSubcategory = true } label: {
                    Chip(text: "New", icon: "plus", iconTint: .accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func subcategoryChip(_ text: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy, action)
        } label: {
            Chip(text: text, icon: icon, iconTint: category?.color, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var detailsSection: some View {
        Section {
            dateRow
            HStack {
                Label("Payment", systemImage: "creditcard")
                Spacer(minLength: 8)
                Menu {
                    Picker("Payment", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.title, systemImage: method.icon).tag(method)
                        }
                    }
                } label: {
                    Label(paymentMethod.title, systemImage: paymentMethod.icon)
                }
            }
            Picker(selection: $recurrence) {
                ForEach(Recurrence.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Label("Repeat", systemImage: "repeat")
            }
            .pickerStyle(.menu)
        }
    }

    private var dateRow: some View {
        let isToday = Calendar.current.isDateInToday(date)
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Label("Date", systemImage: "calendar")
            if !isLargeText { Spacer(minLength: 0) }
            Button {
                date = .now
            } label: {
                Text("Today")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                    .background(isToday ? Color.accentColor.opacity(0.14) : Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.borderless)
            DatePicker("Date", selection: $date)
                .labelsHidden()
        }
    }

    // MARK: Actions

    private func save() {
        guard let amount, amount > 0 else { return }
        let target: Expense
        if let editingExpense {
            target = editingExpense
        } else {
            target = Expense()
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.amount = amount
        target.date = date
        target.category = subcategory ?? category
        target.paymentMethod = paymentMethod
        target.recurrence = recurrence
        target.tags = tags
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        RecurringExpenseProcessor.process(in: context)
        dismiss()
    }

    private func deleteExpense() {
        guard let editingExpense else { return }
        context.delete(editingExpense)
        try? context.save()
        dismiss()
    }
}

private struct CategoryChoice: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                CategoryIcon(category: category, size: 44)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.icon(44) + 4, style: .continuous)
                            .strokeBorder(isSelected ? category.color : Color.clear, lineWidth: 2)
                    )
                Text(category.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TagEditor: View {
    @Binding var tags: [String]
    let suggestions: [String]
    @State private var input = ""

    private var remainingSuggestions: [String] {
        suggestions.filter { suggestion in
            !tags.contains(suggestion) && (input.isEmpty || suggestion.localizedCaseInsensitiveContains(input))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        RemovableChip(text: "#\(tag)") {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            HStack {
                Image(systemName: "tag").foregroundStyle(.secondary)
                TextField("Add a tag", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addTag)
                if !input.isEmpty {
                    Button("Add", action: addTag)
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                }
            }

            if !remainingSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(remainingSuggestions.prefix(15), id: \.self) { suggestion in
                            Button {
                                tags.append(suggestion)
                                input = ""
                            } label: {
                                Chip(text: "#\(suggestion)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func addTag() {
        let tag = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()
        input = ""
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
    }
}

#if DEBUG
private struct EditExpensePreview: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    var body: some View {
        if let expense = expenses.first {
            ExpenseEditorView(route: .edit(expense))
        }
    }
}

#Preview("New light") {
    ExpenseEditorView(route: .new)
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("New dark") {
    ExpenseEditorView(route: .new)
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("New accessibility3") {
    ExpenseEditorView(route: .new)
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}

#Preview("Edit light") {
    EditExpensePreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.light)
}

#Preview("Edit dark") {
    EditExpensePreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.dark)
}

#Preview("Edit accessibility3") {
    EditExpensePreview()
        .modelContainer(PreviewData.container)
        .previewVariant(.accessibility)
}
#endif
