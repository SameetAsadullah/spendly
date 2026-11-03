import Foundation
import SwiftData
import SwiftUI

@Model
final class ExpenseCategory {
    var name: String = ""
    var iconName: String = "tag.fill"
    /// Ignored for a subcategory, which uses its parent's colour.
    var colorHex: String = "#2E86DE"
    /// 0 means no budget.
    var monthlyBudget: Decimal = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

    /// Subcategories are one level deep: a category with a parent has no subcategories.
    var parent: ExpenseCategory?

    @Relationship(deleteRule: .cascade, inverse: \ExpenseCategory.parent)
    var subcategories: [ExpenseCategory]? = []

    init(name: String, iconName: String, colorHex: String, monthlyBudget: Decimal = 0, sortOrder: Int = 0) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.monthlyBudget = monthlyBudget
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}

extension ExpenseCategory {
    var color: Color { Color(hex: parent?.colorHex ?? colorHex) }
    var hasBudget: Bool { monthlyBudget > 0 }
    var expenseCount: Int { expenses?.count ?? 0 }

    var isSubcategory: Bool { parent != nil }
    var mainCategory: ExpenseCategory { parent ?? self }

    var sortedSubcategories: [ExpenseCategory] {
        (subcategories ?? []).sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    var hasSubcategories: Bool { !(subcategories ?? []).isEmpty }

    /// "Parent › Sub" for a subcategory, the name for a main category.
    var path: String {
        guard let parent else { return name }
        return "\(parent.name) › \(name)"
    }

    /// The category's own expenses plus those of its subcategories.
    var allExpenses: [Expense] {
        (expenses ?? []) + (subcategories ?? []).flatMap { $0.expenses ?? [] }
    }

    var totalExpenseCount: Int { allExpenses.count }

    /// Spending in the interval, including subcategories.
    func total(in interval: DateInterval) -> Decimal {
        allExpenses
            .filter { interval.containsHalfOpen($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    /// Chart colour for the subcategory at `index` of `count`: the parent colour at falling opacity.
    static func shade(of base: Color, index: Int, count: Int) -> Color {
        base.opacity(shadeOpacity(index: index, count: count))
    }

    static func shadeOpacity(index: Int, count: Int) -> Double {
        let steps = [1.0, 0.6, 0.35]
        if count <= steps.count { return steps[min(index, steps.count - 1)] }
        return 1 - 0.65 * Double(index) / Double(count - 1)
    }

    /// Deletes the category. A subcategory's expenses move to its parent. A main category takes its
    /// subcategories with it, and their expenses are deleted or left uncategorized.
    func delete(includingExpenses: Bool, in context: ModelContext) {
        if let parent {
            for expense in expenses ?? [] {
                expense.category = parent
            }
        } else {
            if includingExpenses {
                for expense in allExpenses {
                    context.delete(expense)
                }
            }
            for subcategory in subcategories ?? [] {
                context.delete(subcategory)
            }
        }
        context.delete(self)
    }
}
