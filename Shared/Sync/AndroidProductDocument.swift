import CoreData
import Foundation

/// Reads the Android app's product documents.
///
/// Same story as the receipts: different names for the same things. Android calls
/// the price `sellingPrice`, timestamps are epoch milliseconds, and identity lives
/// in `productUuid` rather than the document id — its `id` is a local row number
/// that means nothing across devices.
///
/// Nullable where iOS is not: `category`, `notes` and `costPrice` all come through
/// as null on products entered quickly, so every read has to tolerate it.
enum AndroidProductDocument {
    static func matches(_ document: [String: Any]) -> Bool {
        document["productUuid"] != nil
            || document["sellingPrice"] != nil
            || (document["unit"] != nil && document["isArchived"] != nil)
    }

    /// Android's own UUID when it has one, so the same product lands on the same
    /// row every sync. Falling back to the document id keeps it stable either way.
    static func localID(_ document: [String: Any], documentID: String) -> UUID {
        if let text = document["productUuid"] as? String, let parsed = UUID(uuidString: text) {
            return parsed
        }
        return AndroidReceiptDocument.localID(forDocument: "product.\(documentID)")
    }

    static func apply(_ document: [String: Any], to product: CDProduct) {
        product.name = string(document["name"])
        product.category = string(document["category"])
        let unit = string(document["unit"])
        product.unit = unit.isEmpty ? "piece" : unit
        product.notes = string(document["notes"])
        product.price = decimal(document["sellingPrice"])
        product.isArchived = document["isArchived"] as? Bool ?? false

        // Only present on products Android tracks stock for.
        if let barcode = document["barcode"] as? String, !barcode.isEmpty {
            product.barcode = barcode
        }
        if let stock = document["stock"] as? NSNumber {
            product.stock = stock.int32Value
        }
        if let threshold = document["lowStockThreshold"] as? NSNumber {
            product.lowStockThreshold = threshold.int32Value
        }

        let updated = AndroidReceiptDocument.date(document["lastUpdated"]) ?? Date()
        product.updatedAt = updated
    }

    static func dictionary(from product: CDProduct) -> [String: Any] {
        var document: [String: Any] = [
            "productUuid": product.id.uuidString,
            "name": product.name,
            "category": product.category,
            "unit": product.unit,
            "notes": product.notes,
            "sellingPrice": product.price.doubleValue,
            "costPrice": 0,
            "isArchived": product.isArchived,
            "stock": Int(product.stock),
            "lowStockThreshold": Int(product.lowStockThreshold),
            "lastUpdated": Int((product.updatedAt ?? Date()).timeIntervalSince1970 * 1000)
        ]
        if let barcode = product.barcode, !barcode.isEmpty {
            document["barcode"] = barcode
        }
        return document
    }

    // MARK: - Coercion

    private static func string(_ value: Any?) -> String {
        (value as? String) ?? ""
    }

    private static func decimal(_ value: Any?) -> NSDecimalNumber {
        guard let number = value as? NSNumber else { return .zero }
        let parsed = NSDecimalNumber(string: number.stringValue)
        return parsed == NSDecimalNumber.notANumber ? .zero : parsed
    }
}
