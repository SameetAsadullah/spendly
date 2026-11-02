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
    @State private var paymentMethod: PaymentMethod
    @State private var recurrence: Recurrence
    @State private var tags: [String]
    @State private var notes: String
    @State private var showNewCategory = false
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
        _category = State(initialValue: source?.category ?? presetCategory)
        _paymentMethod = State(initialValue: source?.paymentMethod ?? .card)
        _recurrence = State(initialValue: isEdit ? (source?.recurrence ?? .never) : .never)
        _tags = State(initialValue: source?.tags ?? [])
        _notes = State(initialValue: source?.notes ?? "")
    }

    private var editingExpense: Expense? {
        if case .edit(let expense) = route { return expense }
        return nil
    }

    private var amount: Double? { AmountParser.parse(amountText) }
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
                            .frame(maxWidth: .infinity)
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
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: deleteExpense)
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                if case .new = route, category == nil {
                    category = categories.first
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

    private var amountSection: some View {
        Section {
            VStack(spacing: 6) {
                Text("Amount")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(AppSettings.currencySymbol(for: currency))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $amountText)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .fixedSize()
                        .onChange(of: amountText) { _, newValue in
                            let cleaned = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                            if cleaned != newValue { amountText = cleaned }
                        }
                }
                .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }
        }
        .listRowBackground(Color.clear)
    }

    private var categorySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                ForEach(categories) { item in
                    CategoryChoice(category: item, isSelected: category == item) {
                        withAnimation(.snappy) { category = item }
                    }
                }
                Button { showNewCategory = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        Text("New").font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Category")
        } footer: {
            if category == nil {
                Text("No category selected. This expense will be Uncategorized.")
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title (e.g. Lunch with team)", text: $title)
                .textInputAutocapitalization(.sentences)
            DatePicker("Date", selection: $date)
            Picker(selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    Label(method.title, systemImage: method.icon).tag(method)
                }
            } label: {
                Label("Payment", systemImage: "creditcard")
            }
            Picker(selection: $recurrence) {
                ForEach(Recurrence.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Label("Repeat", systemImage: "repeat")
            }
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
        target.category = category
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
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? category.color.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
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
                Image(systemName: "number").foregroundStyle(.secondary)
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
