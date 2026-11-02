import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var categories: [ExpenseCategory]
    @AppStorage(AppSettings.currencyKey) private var currency = AppSettings.defaultCurrency
    @AppStorage(AppSettings.monthlyBudgetKey) private var monthlyBudget = 0.0
    @AppStorage(AppSettings.appearanceKey) private var appearance: Appearance = .system

    @State private var confirmDeleteAll = false

    private var budgetBinding: Binding<Double?> {
        Binding(
            get: { monthlyBudget > 0 ? monthlyBudget : nil },
            set: { monthlyBudget = max($0 ?? 0, 0) }
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
                            Text("\(currency) · \(AppSettings.currencySymbol(for: currency))")
                        } label: {
                            Label("Currency", systemImage: "dollarsign.circle.fill")
                        }
                    }
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("Changing the currency changes how amounts are shown. It does not convert them.")
                }

                Section {
                    HStack {
                        Label("Monthly budget", systemImage: "target")
                        Spacer()
                        AmountField(placeholder: "None", value: budgetBinding)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                } header: {
                    Text("Budget")
                } footer: {
                    Text("Your overall spending limit for each month, shown on the Overview. Set per-category budgets in Categories.")
                }

                Section("Data") {
                    ShareLink(
                        item: CSVDocument(expenses: expenses, currency: currency, fileName: "All-Expenses"),
                        preview: SharePreview("All expenses (CSV)")
                    ) {
                        Label("Export All Expenses (CSV)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)

                    Button {
                        SampleData.insertSampleExpenses(in: context)
                    } label: {
                        Label("Add Sample Expenses", systemImage: "wand.and.stars")
                    }

                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Delete All Expenses", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(expenses.isEmpty)
                }

                Section("About") {
                    LabeledContent("Expenses", value: "\(expenses.count)")
                    LabeledContent("Categories", value: "\(categories.count)")
                    LabeledContent("Version", value: AppSettings.appVersion)
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog(
                "Delete all \(expenses.count) expenses?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete All Expenses", role: .destructive, action: deleteAllExpenses)
            } message: {
                Text("Categories are kept. This cannot be undone. Export a CSV first if you want a backup.")
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
        List(filteredCodes, id: \.self) { code in
            Button {
                selection = code
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Text(AppSettings.currencySymbol(for: code))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AppSettings.currencyName(for: code))
                            .foregroundStyle(Color.primary)
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if code == selection {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search currencies")
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
