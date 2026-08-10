import CoreData
import Foundation

/// Translation between Core Data objects and the plain dictionaries Firestore
/// stores.
///
/// Hand-rolled rather than `Codable` via FirebaseFirestoreSwift so the shape is
/// explicit and shared with the Android app — both platforms read and write these
/// exact field names in `users/{uid}/receipts` and `users/{uid}/members`.
enum ReceiptDocument {
    /// A single Firestore document must stay under 1 MB. Signatures are the only
    /// field that can grow, so an unusually large one is dropped rather than
    /// failing the whole write.
    static let maxSignatureBytes = 400_000

    // MARK: - Receipts

    static func dictionary(from receipt: CDReceipt) -> [String: Any] {
        var document: [String: Any] = [
            "id": receipt.id.uuidString,
            "number": receipt.number,
            "createdAt": receipt.createdAt,
            "updatedAt": receipt.updatedAt ?? receipt.createdAt,
            "title": receipt.title,
            "storeName": receipt.storeName,
            "address": receipt.address,
            "customerName": receipt.customerName,
            "customerPhone": receipt.customerPhone,
            "customerEmail": receipt.customerEmail,
            "customerAddress": receipt.customerAddress,
            "currencyCode": receipt.currencyCode,
            "category": receipt.categoryRaw,
            "paymentMethod": receipt.paymentMethodRaw,
            "discountType": receipt.discountTypeRaw,
            // Decimals travel as strings so no cent is lost to a double.
            "discountValue": receipt.discountValue.stringValue,
            "taxPercent": receipt.taxPercent.stringValue,
            "cashGiven": receipt.cashGiven.stringValue,
            "note": receipt.note,
            "notesPageTwo": receipt.notesPageTwo,
            "issuedByName": receipt.issuedByName,
            "issuedByEmail": receipt.issuedByEmail,
            "isArchived": receipt.isArchived,
            "items": receipt.orderedItems.map { item in
                [
                    "id": item.id.uuidString,
                    "name": item.name,
                    "quantity": Int(item.quantity),
                    "unitPrice": item.unitPrice.stringValue,
                    "sortIndex": Int(item.sortIndex)
                ] as [String: Any]
            }
        ]

        if let latitude = receipt.latitude?.doubleValue { document["latitude"] = latitude }
        if let longitude = receipt.longitude?.doubleValue { document["longitude"] = longitude }
        if let memberID = receipt.memberID { document["memberID"] = memberID.uuidString }
        if let signature = receipt.signaturePNG, signature.count <= maxSignatureBytes {
            document["signature"] = signature.base64EncodedString()
        }

        return document
    }

    /// Writes a remote document onto `receipt`, replacing its items wholesale —
    /// a receipt's lines are small and always travel together.
    static func apply(_ document: [String: Any], to receipt: CDReceipt, in context: NSManagedObjectContext) {
        receipt.number = document["number"] as? String ?? receipt.number
        receipt.createdAt = date(document["createdAt"]) ?? receipt.createdAt
        receipt.updatedAt = date(document["updatedAt"])
        receipt.title = document["title"] as? String ?? ""
        receipt.storeName = document["storeName"] as? String ?? ""
        receipt.address = document["address"] as? String ?? ""
        receipt.latitude = (document["latitude"] as? Double).map { NSNumber(value: $0) }
        receipt.longitude = (document["longitude"] as? Double).map { NSNumber(value: $0) }
        receipt.memberID = (document["memberID"] as? String).flatMap(UUID.init(uuidString:))
        receipt.customerName = document["customerName"] as? String ?? ""
        receipt.customerPhone = document["customerPhone"] as? String ?? ""
        receipt.customerEmail = document["customerEmail"] as? String ?? ""
        receipt.customerAddress = document["customerAddress"] as? String ?? ""
        receipt.currencyCode = document["currencyCode"] as? String ?? Currency.pkr.code
        receipt.categoryRaw = document["category"] as? String ?? ReceiptCategory.other.rawValue
        receipt.paymentMethodRaw = document["paymentMethod"] as? String ?? PaymentMethod.cash.rawValue
        receipt.discountTypeRaw = document["discountType"] as? String ?? DiscountType.none.rawValue
        receipt.discountValue = decimal(document["discountValue"])
        receipt.taxPercent = decimal(document["taxPercent"])
        receipt.cashGiven = decimal(document["cashGiven"])
        receipt.note = document["note"] as? String ?? ""
        receipt.notesPageTwo = document["notesPageTwo"] as? String ?? ""
        receipt.issuedByName = document["issuedByName"] as? String ?? ""
        receipt.issuedByEmail = document["issuedByEmail"] as? String ?? ""
        receipt.isArchived = document["isArchived"] as? Bool ?? false

        if let encoded = document["signature"] as? String {
            receipt.signaturePNG = Data(base64Encoded: encoded)
        }

        receipt.orderedItems.forEach(context.delete)
        let rows = document["items"] as? [[String: Any]] ?? []
        for row in rows {
            let item = CDReceiptItem(context: context)
            item.id = (row["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            item.name = row["name"] as? String ?? ""
            item.quantity = Int32(row["quantity"] as? Int ?? 1)
            item.unitPrice = decimal(row["unitPrice"])
            item.sortIndex = Int32(row["sortIndex"] as? Int ?? 0)
            item.receipt = receipt
        }
    }

    // MARK: - Members

    static func dictionary(from member: CDMember) -> [String: Any] {
        var document: [String: Any] = [
            "id": member.id.uuidString,
            "name": member.name,
            "phone": member.phone,
            "email": member.email,
            "notes": member.notes,
            "createdAt": member.createdAt,
            "updatedAt": member.updatedAt ?? member.createdAt
        ]
        if let avatar = member.avatarPNG, avatar.count <= maxSignatureBytes {
            document["avatar"] = avatar.base64EncodedString()
        }
        return document
    }

    static func apply(_ document: [String: Any], to member: CDMember) {
        member.name = document["name"] as? String ?? ""
        member.phone = document["phone"] as? String ?? ""
        member.email = document["email"] as? String ?? ""
        member.notes = document["notes"] as? String ?? ""
        member.createdAt = date(document["createdAt"]) ?? Date()
        member.updatedAt = date(document["updatedAt"])
        if let encoded = document["avatar"] as? String {
            member.avatarPNG = Data(base64Encoded: encoded)
        }
    }

    // MARK: - Coercion

    /// Firestore hands back `Timestamp`, but a document written by another client
    /// may carry an ISO-8601 string or epoch seconds instead.
    static func date(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let seconds = value as? Double { return Date(timeIntervalSince1970: seconds) }
        if let text = value as? String { return ISO8601DateFormatter().date(from: text) }
        // `FIRTimestamp` responds to `dateValue()` without importing Firestore here.
        if let object = value as? NSObject, object.responds(to: Selector(("dateValue"))) {
            return object.value(forKey: "dateValue") as? Date
        }
        return nil
    }

    private static func decimal(_ value: Any?) -> NSDecimalNumber {
        if let text = value as? String {
            let parsed = NSDecimalNumber(string: text)
            return parsed == NSDecimalNumber.notANumber ? .zero : parsed
        }
        if let number = value as? NSNumber {
            return NSDecimalNumber(decimal: number.decimalValue)
        }
        return .zero
    }
}
