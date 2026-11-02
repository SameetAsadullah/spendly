import Foundation
import SwiftData
import SwiftUI

@Model
final class ExpenseCategory {
    var name: String = ""
    var iconName: String = "tag.fill"
    var colorHex: String = "#2E86DE"
    /// 0 means no budget.
    var monthlyBudget: Decimal = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

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
    var color: Color { Color(hex: colorHex) }
    var hasBudget: Bool { monthlyBudget > 0 }
    var expenseCount: Int { expenses?.count ?? 0 }
}
