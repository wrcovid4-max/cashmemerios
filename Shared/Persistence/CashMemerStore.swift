import Foundation
import SwiftData

/// Central definition of the SwiftData stack so the app, the watch extension and
/// previews all agree on the schema.
enum CashMemerStore {
    static let schema = Schema([Receipt.self, ReceiptItem.self, Member.self])

    static func container(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            // Receipts hold customer contact details, so keep the store on-device
            // unless the user explicitly opts into cloud backup.
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to open the Cash Memer store: \(error)")
        }
    }

    /// In-memory container seeded with sample data, used by SwiftUI previews.
    @MainActor
    static func previewContainer() -> ModelContainer {
        let container = container(inMemory: true)
        let context = container.mainContext

        let member = Member(name: "Umer Butt", phone: "0304 4545431", email: "wr.covid.4@gmail.com")
        context.insert(member)
        context.insert(Member(name: "Tahira Mujahid", phone: "0321 4242862"))

        let receipt = Receipt(
            number: "84AC83A",
            title: "Chapters",
            storeName: "Chapters",
            address: "281, Sector FF Dha Phase 4, Lahore, Pakistan",
            latitude: 31.464347,
            longitude: 74.390228,
            memberID: member.id,
            customerName: "Umer Butt",
            category: .shopping,
            paymentMethod: .cash,
            note: "Thank you for shopping!"
        )
        context.insert(receipt)
        let item = ReceiptItem(name: "Piano Ball Point", quantity: 1, unitPrice: 350, receipt: receipt)
        context.insert(item)
        receipt.items = [item]

        return container
    }
}

// MARK: - Queries

extension Receipt {
    static func activeDescriptor(searchText: String = "") -> FetchDescriptor<Receipt> {
        var descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if !searchText.isEmpty {
            descriptor.predicate = #Predicate {
                !$0.isArchived && (
                    $0.storeName.localizedStandardContains(searchText)
                    || $0.title.localizedStandardContains(searchText)
                    || $0.customerName.localizedStandardContains(searchText)
                    || $0.number.localizedStandardContains(searchText)
                )
            }
        }
        return descriptor
    }

    static var archivedDescriptor: FetchDescriptor<Receipt> {
        FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
}
