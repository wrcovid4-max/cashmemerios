import AppIntents
import CoreData
import Foundation

/// A receipt exposed to Siri, Shortcuts and Spotlight as a first-class entity, so
/// it can be passed between shortcut actions instead of being flattened to text.
@available(iOS 16.0, watchOS 9.0, *)
struct ReceiptEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Receipt", numericFormat: "\(placeholder: .int) receipts")
    }

    static var defaultQuery = ReceiptEntityQuery()

    var id: UUID
    @Property(title: "Receipt Number") var number: String
    @Property(title: "Store") var store: String
    @Property(title: "Total") var total: Double
    @Property(title: "Currency") var currencyCode: String
    @Property(title: "Date") var date: Date
    @Property(title: "Category") var category: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(store.isEmpty ? "Receipt" : store)",
            subtitle: "\(currencyCode) \(String(format: "%.2f", total)) · \(number)"
        )
    }

    init(receipt: CDReceipt) {
        id = receipt.id
        number = receipt.number
        store = receipt.storeName.isEmpty ? receipt.title : receipt.storeName
        total = NSDecimalNumber(decimal: receipt.totals.grandTotal).doubleValue
        currencyCode = receipt.currencyCode
        date = receipt.createdAt
        category = receipt.category.rawValue
    }
}

@available(iOS 16.0, watchOS 9.0, *)
struct ReceiptEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReceiptEntity] {
        try await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = CDReceipt.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", identifiers)
            return try context.fetch(request).map(ReceiptEntity.init(receipt:))
        }
    }

    /// The list Shortcuts shows when the user taps the parameter — most recent first.
    func suggestedEntities() async throws -> [ReceiptEntity] {
        try await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = CDReceipt.activeRequest()
            request.fetchLimit = 10
            return try context.fetch(request).map(ReceiptEntity.init(receipt:))
        }
    }
}

@available(iOS 16.0, watchOS 9.0, *)
extension ReceiptEntityQuery: EntityStringQuery {
    /// Backs "find my receipt from Chapters" — matches store, customer or number.
    func entities(matching string: String) async throws -> [ReceiptEntity] {
        try await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = CDReceipt.activeRequest(search: string)
            request.fetchLimit = 25
            return try context.fetch(request).map(ReceiptEntity.init(receipt:))
        }
    }
}
