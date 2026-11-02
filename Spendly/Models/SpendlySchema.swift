import SwiftData

/// Before you change a stored property, freeze these models as a nested copy in this enum,
/// add `SpendlySchemaV2` with the new models, and add a stage to `SpendlyMigrationPlan`.
enum SpendlySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }
}

enum SpendlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SpendlySchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}

extension ModelContainer {
    static func spendly(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SpendlySchemaV1.self),
            migrationPlan: SpendlyMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
