import CoreData
import CoreSpotlight
import Foundation

/// Indexes every receipt into Spotlight automatically as Core Data changes.
///
/// Using `NSCoreDataCoreSpotlightDelegate` rather than hand-rolled indexing means
/// deletes and edits stay in sync for free, including changes made by the widget
/// extension or an App Intent running outside the app.
final class ReceiptSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        SpotlightIndex.domainIdentifier
    }

    override func indexName() -> String? {
        "cash-memer-receipts"
    }

    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        guard let receipt = object as? CDReceipt else { return nil }
        return SpotlightIndex.attributeSet(for: receipt)
    }
}

enum SpotlightIndex {
    static let domainIdentifier = "com.cashmemer.receipt"
    /// Continuation activity type used when the user taps a Spotlight result.
    static let activityType = "com.cashmemer.viewReceipt"

    static func attributeSet(for receipt: CDReceipt) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)

        let store = receipt.storeName.isEmpty ? receipt.title : receipt.storeName
        attributes.title = store.isEmpty ? "Receipt \(receipt.number)" : store
        attributes.contentDescription = description(for: receipt)
        attributes.identifier = receipt.id.uuidString
        attributes.relatedUniqueIdentifier = receipt.id.uuidString
        attributes.contentCreationDate = receipt.createdAt
        attributes.displayName = attributes.title

        // Everything a user might plausibly type into Spotlight to find this memo.
        var keywords = [receipt.number, store, receipt.customerName, receipt.category.rawValue]
        keywords.append(contentsOf: receipt.orderedItems.map(\.name))
        attributes.keywords = keywords.filter { !$0.isEmpty }

        if !receipt.address.isEmpty {
            attributes.namedLocation = receipt.address
        }
        if let latitude = receipt.latitude, let longitude = receipt.longitude {
            attributes.latitude = latitude
            attributes.longitude = longitude
        }

        return attributes
    }

    private static func description(for receipt: CDReceipt) -> String {
        let total = CurrencyFormatter.string(receipt.totals.grandTotal, currency: receipt.currency)
        let date = receipt.createdAt.formatted(date: .abbreviated, time: .shortened)
        let itemCount = receipt.orderedItems.count
        let items = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(total) · \(items) · \(date)"
    }

    /// Deep link carried by Spotlight results and Siri shortcuts.
    static func url(for receiptID: UUID) -> URL? {
        URL(string: "cashmemer://receipt/\(receiptID.uuidString)")
    }
}
