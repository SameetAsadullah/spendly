import SwiftData
import SwiftUI

extension View {
    /// Confirms deleting a category. A subcategory's expenses move to its parent; for a main category
    /// the user chooses between keeping and deleting the expenses of it and its subcategories.
    func categoryDeleteDialog(_ pending: Binding<ExpenseCategory?>, onDelete: (() -> Void)? = nil) -> some View {
        modifier(CategoryDeleteDialog(pending: pending, onDelete: onDelete))
    }
}

private struct CategoryDeleteDialog: ViewModifier {
    @Environment(\.modelContext) private var context
    @Binding var pending: ExpenseCategory?
    let onDelete: (() -> Void)?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete “\(pending?.name ?? "category")”?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { category in
            let count = category.totalExpenseCount
            if category.isSubcategory {
                Button("Delete Subcategory", role: .destructive) {
                    delete(category, includingExpenses: false)
                }
            } else if count > 0 {
                Button("Delete Category Only", role: .destructive) {
                    delete(category, includingExpenses: false)
                }
                Button("Delete Category and \(count) \(count == 1 ? "Expense" : "Expenses")", role: .destructive) {
                    delete(category, includingExpenses: true)
                }
            } else {
                Button("Delete Category", role: .destructive) {
                    delete(category, includingExpenses: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            Text(message(for: category))
        }
    }

    private func message(for category: ExpenseCategory) -> String {
        let count = category.totalExpenseCount
        if let parent = category.parent {
            return count > 0
                ? "\(count) \(count == 1 ? "expense moves" : "expenses move") to \(parent.name)."
                : "This subcategory has no expenses."
        }
        let subcount = category.subcategories?.count ?? 0
        let scope = subcount > 0 ? " and its \(subcount) \(subcount == 1 ? "subcategory" : "subcategories")" : ""
        if count > 0 {
            return "\(count) \(count == 1 ? "expense uses" : "expenses use") this category\(scope). Keep them as Uncategorized, or delete them with the category."
        }
        return "This category\(scope) has no expenses."
    }

    private func delete(_ category: ExpenseCategory, includingExpenses: Bool) {
        withAnimation {
            category.delete(includingExpenses: includingExpenses, in: context)
            try? context.save()
        }
        onDelete?()
    }
}
