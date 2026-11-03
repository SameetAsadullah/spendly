import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @AppStorage(AppSettings.monthlyBudgetKey) private var storedMonthlyBudget = 0.0
    @AppStorage(AppSettings.appearanceKey) private var appearance: Appearance = .system
    @AppStorage(AppSettings.appLockKey) private var appLockEnabled = false

    @State private var confirmDeleteAll = false

    private var budgetBinding: Binding<Decimal?> {
        Binding(
            get: { storedMonthlyBudget > 0 ? Decimal(roundTripping: storedMonthlyBudget) : nil },
            set: { storedMonthlyBudget = max($0 ?? 0, 0).doubleValue }
        )
    }

    /// Turning the lock on asks for authentication first, so a failing method cannot lock the user out.
    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { isOn in
                guard isOn else {
                    appLockEnabled = false
                    return
                }
                Task {
                    if await DeviceAuth.authenticate(reason: "Confirm that you can unlock Spendly.") {
                        appLockEnabled = true
                    }
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CurrencyPickerView(selection: $currency)
                    } label: {
                        LabeledContent {
                            Text("\(currency) \(AppSettings.currencySymbol(for: currency))")
                        } label: {
                            SettingsLabel("Currency", systemImage: "dollarsign.circle")
                        }
                    }
                    HStack {
                        SettingsLabel("Monthly Budget", systemImage: "target")
                        Spacer(minLength: 8)
                        AmountField(placeholder: "None", value: budgetBinding)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsLabel("Appearance", systemImage: "circle.lefthalf.filled")
                        Picker("Appearance", selection: $appearance) {
                            ForEach(Appearance.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("General")
                } footer: {
                    Text("The budget drives the bar on the Overview. Leave it empty to hide it. Changing the currency changes how amounts are shown. It does not convert them.")
                }

                Section {
                    Toggle(isOn: appLockBinding) {
                        SettingsLabel("Require \(DeviceAuth.methodName)", systemImage: DeviceAuth.iconName)
                    }
                    .disabled(!DeviceAuth.isAvailable && !appLockEnabled)
                } header: {
                    Text("Security")
                } footer: {
                    Text(DeviceAuth.isAvailable
                         ? "Spendly asks for \(DeviceAuth.methodName) before it shows your expenses."
                         : "Set a passcode on this device to lock Spendly.")
                }

                Section {
                    ShareLink(
                        item: CSVDocument(expenses: expenses, currency: currency, fileName: "All-Expenses"),
                        preview: SharePreview("All expenses (CSV)")
                    ) {
                        SettingsLabel("Export All Expenses as CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)

                    Button {
                        SampleData.insertSampleExpenses(in: context)
                    } label: {
                        SettingsLabel("Add Sample Expenses", systemImage: "sparkles")
                    }

                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Delete All Expenses", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(expenses.isEmpty)
                } header: {
                    Text("Data")
                } footer: {
                    Text("Your expenses are stored only on this device. There is no account and no sync.")
                }

                Section("About") {
                    LabeledContent {
                        Text("\(expenses.count)")
                    } label: {
                        SettingsLabel("Expenses", systemImage: "list.bullet")
                    }
                    LabeledContent {
                        Text("\(categories.count)")
                    } label: {
                        SettingsLabel("Categories", systemImage: "square.grid.2x2")
                    }
                    LabeledContent {
                        Text(AppSettings.appVersion)
                    } label: {
                        SettingsLabel("Version", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .alert("Delete All Expenses?", isPresented: $confirmDeleteAll) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteAllExpenses)
            } message: {
                Text("This permanently removes all \(expenses.count) \(expenses.count == 1 ? "expense" : "expenses") from this device. Categories and settings stay. This can’t be undone.")
            }
        }
    }

    private func deleteAllExpenses() {
        for expense in expenses {
            context.delete(expense)
        }
        try? context.save()
    }
}

/// A row label whose symbol uses the accent color.
private struct SettingsLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.tint)
        }
    }
}

struct CurrencyPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private static let codes: [String] = Locale.commonISOCurrencyCodes

    private var filteredCodes: [String] {
        guard !search.isEmpty else { return Self.codes }
        return Self.codes.filter {
            $0.localizedCaseInsensitiveContains(search)
                || AppSettings.currencyName(for: $0).localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            if search.isEmpty {
                Section("Selected") {
                    row(for: selection)
                }
            }
            Section("All Currencies") {
                ForEach(filteredCodes, id: \.self) { code in
                    row(for: code)
                }
            }
        }
        .searchable(text: $search, prompt: "Search currencies")
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for code: String) -> some View {
        Button {
            selection = code
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppSettings.currencyName(for: code))
                        .foregroundStyle(Color.primary)
                    Text("\(code) · \(AppSettings.currencySymbol(for: code))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if code == selection {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityAddTraits(code == selection ? .isSelected : [])
    }
}

#if DEBUG
#Preview("Settings, light") {
    SettingsView().modelContainer(PreviewData.container).previewVariant(.light)
}

#Preview("Settings, dark") {
    SettingsView().modelContainer(PreviewData.container).previewVariant(.dark)
}

#Preview("Settings, accessibility3") {
    SettingsView().modelContainer(PreviewData.container).previewVariant(.accessibility)
}

#Preview("Currency, light") {
    NavigationStack { CurrencyPickerView(selection: .constant("USD")) }.previewVariant(.light)
}

#Preview("Currency, dark") {
    NavigationStack { CurrencyPickerView(selection: .constant("USD")) }.previewVariant(.dark)
}

#Preview("Currency, accessibility3") {
    NavigationStack { CurrencyPickerView(selection: .constant("USD")) }.previewVariant(.accessibility)
}
#endif
