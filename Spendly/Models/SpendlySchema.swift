import Foundation
import SwiftData

/// Before you change a stored property, freeze the current models as nested copies in the latest
/// schema enum, add a new schema with the live models, and add a stage to `SpendlyMigrationPlan`.
enum SpendlySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }

    // Frozen copies of the shipped 1.0 models. They must match the stores on devices exactly.

    @Model
    final class Expense {
        var title: String = ""
        var amount: Decimal = 0
        var date: Date = Date.now
        var notes: String = ""
        var paymentMethodRaw: String = "card"
        var tags: [String] = []
        var recurrenceRaw: String = "never"
        var createdAt: Date = Date.now
        var category: ExpenseCategory?

        init(title: String = "", amount: Decimal = 0, date: Date = .now) {
            self.title = title
            self.amount = amount
            self.date = date
        }
    }

    @Model
    final class ExpenseCategory {
        var name: String = ""
        var iconName: String = "tag.fill"
        var colorHex: String = "#2E86DE"
        var monthlyBudget: Decimal = 0
        var sortOrder: Int = 0
        var createdAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \Expense.category)
        var expenses: [Expense]? = []

        init(name: String, iconName: String = "tag.fill", colorHex: String = "#2E86DE", monthlyBudget: Decimal = 0) {
            self.name = name
            self.iconName = iconName
            self.colorHex = colorHex
            self.monthlyBudget = monthlyBudget
        }
    }
}

/// Adds subcategories: `ExpenseCategory.parent` and its inverse `subcategories`.
enum SpendlySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }
}

enum SpendlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SpendlySchemaV1.self, SpendlySchemaV2.self]
    }

    static var stages: [MigrationStage] { [v1ToV2] }

    /// The new relationship is optional, so every existing category opens as a main category.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SpendlySchemaV1.self, toVersion: SpendlySchemaV2.self)
}

extension ModelContainer {
    static func spendly(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = if let url {
            ModelConfiguration(url: url)
        } else {
            ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: Schema(versionedSchema: SpendlySchemaV2.self),
            migrationPlan: SpendlyMigrationPlan.self,
            configurations: configuration
        )
    }
}
