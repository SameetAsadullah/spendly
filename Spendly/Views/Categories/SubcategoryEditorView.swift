import SwiftData
import SwiftUI

/// The New and Edit Subcategory sheet.
struct SubcategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// nil creates a new subcategory.
    let subcategory: ExpenseCategory?
    /// The preset parent for a new subcategory.
    let parent: ExpenseCategory?
    var onSave: ((ExpenseCategory) -> Void)?

    init(subcategory: ExpenseCategory? = nil, parent: ExpenseCategory? = nil, onSave: ((ExpenseCategory) -> Void)? = nil) {
        self.subcategory = subcategory
        self.parent = parent ?? subcategory?.parent
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView("New Subcategory", systemImage: "square.grid.2x2")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
