import CoreData
import CryptoKit
import Foundation

/// Reads and writes the Android app's Firestore documents.
///
/// The two apps were written independently and agree on almost nothing: Android
/// calls the store `place`, note 2 `notePage2`, and the GPS address
/// `locationAddress`; it stores money as doubles rather than strings, timestamps
/// as epoch **milliseconds** rather than Firestore `Timestamp`s, and — most
/// importantly — its `id` is the printed receipt number as an integer, not a UUID.
///
/// The iOS listener required `id` to parse as a UUID, so every Android receipt
/// failed that check and was skipped without a word. Sync reported success and
/// nothing arrived.
///
/// Rather than migrate one side onto the other's schema, this translates. Android
/// documents keep their shape and their document id, so the Android app carries on
/// reading and writing them exactly as before.
enum AndroidReceiptDocument {
    // MARK: - Recognition

    /// Android documents are told apart by shape, not by which collection they
    /// live in — the two apps may well share one.
    ///
    /// `place` and `notePage2` are Android-only names, and an `id` that is a
    /// number rather than a UUID string settles it on its own.
    static func matches(_ document: [String: Any]) -> Bool {
        if document["place"] != nil || document["notePage2"] != nil { return true }
        if document["taxPercentage"] != nil || document["locationAddress"] != nil { return true }
        // An `id` that is not a UUID string cannot be an iOS document.
        if let id = document["id"], !(id is String) { return true }
        return false
    }

    // MARK: - Identity

    /// A stable UUID for an Android document.
    ///
    /// Android numbers its receipts 1, 2, 3…, which says nothing about identity
    /// across devices, so the Core Data id is derived from the Firestore document
    /// id instead. Deriving rather than generating matters: re-syncing the same
    /// document has to land on the same local receipt, or every sync would add
    /// another copy.
    static func localID(forDocument documentID: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data("cashmemer.android.\(documentID)".utf8))
        var bytes = Array(digest)
        // Stamp version 5 and the RFC 4122 variant so the result is a well-formed
        // UUID rather than 16 arbitrary bytes.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Remote → local

    static func apply(
        _ document: [String: Any],
        to receipt: CDReceipt,
        documentID: String,
        in context: NSManagedObjectContext
    ) {
        receipt.remoteDocID = documentID
        receipt.number = numberText(document["id"]) ?? receipt.number

        // `createdAt` is a non-optional Date with no default in the model, so on a
        // freshly inserted CDReceipt it is nil until something assigns it. Using it
        // as the `??` fallback reads it while still nil, and bridging nil to a
        // non-optional Date traps in Date._unconditionallyBridgeFromObjectiveC —
        // which is exactly how a document missing `timestamp` crashed the app.
        // Fall back to a value that always exists.
        let created = date(document["timestamp"]) ?? Date()
        receipt.createdAt = created
        receipt.updatedAt = date(document["lastModified"]) ?? created

        receipt.title = string(document["title"])
        // Android's `place` is the store; its `locationAddress` is the GPS fix.
        receipt.storeName = string(document["place"])
        receipt.address = string(document["locationAddress"])
        receipt.latitude = (document["latitude"] as? Double).map { NSNumber(value: $0) }
        receipt.longitude = (document["longitude"] as? Double).map { NSNumber(value: $0) }

        receipt.customerName = string(document["customerName"])
        receipt.customerPhone = string(document["customerPhone"])
        receipt.customerEmail = string(document["customerEmail"])
        receipt.customerAddress = string(document["customerAddress"])

        receipt.currencyCode = string(document["currency"], fallback: Currency.usd.code)
        receipt.categoryRaw = category(string(document["category"]))
        receipt.paymentMethodRaw = paymentMethod(string(document["paymentType"]))
        receipt.discountTypeRaw = discountType(string(document["discountType"]))
        receipt.discountValue = decimal(document["discountValue"])
        receipt.taxPercent = decimal(document["taxPercentage"])
        receipt.cashGiven = decimal(document["cashGiven"])

        receipt.note = string(document["note"])
        receipt.notesPageTwo = string(document["notePage2"])
        receipt.issuedByName = string(document["accountName"])
        receipt.issuedByEmail = string(document["accountEmail"])
        receipt.isArchived = document["isArchived"] as? Bool ?? false
        receipt.memberID = (document["memberID"] as? String).flatMap(UUID.init(uuidString:))
        receipt.markupJSON = document["markupJSON"] as? String

        // `signaturePath` points at a file inside the Android sandbox and is of no
        // use here; only the inline base64 copy can be read.
        if let encoded = document["signatureBase64"] as? String, !encoded.isEmpty {
            receipt.signaturePNG = Data(base64Encoded: encoded)
        }

        receipt.orderedItems.forEach(context.delete)
        let rows = document["items"] as? [[String: Any]] ?? []
        for (index, row) in rows.enumerated() {
            let item = CDReceiptItem(context: context)
            item.id = localID(forDocument: "\(documentID)#\(index)")
            item.name = string(row["name"])

            let quantity = max(1, Int(numberValue(row["quantity"]) ?? 1))
            item.quantity = Int32(quantity)
            // Android stores the line total; iOS stores the unit price and
            // multiplies. Dividing here keeps both showing the same figure.
            item.unitPrice = decimal(row["totalPrice"]).dividing(
                by: NSDecimalNumber(value: quantity),
                withBehavior: NSDecimalNumberHandler(
                    roundingMode: .plain,
                    scale: 6,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )
            )
            item.sortIndex = Int32(index)
            item.receipt = receipt
        }
    }

    // MARK: - Local → remote

    /// Writes a receipt back in Android's shape, so a memo edited on iOS stays
    /// readable on the phone it came from.
    static func dictionary(from receipt: CDReceipt) -> [String: Any] {
        let totals = receipt.totals
        var document: [String: Any] = [
            "id": Int(receipt.number) ?? 0,
            "timestamp": Int(receipt.createdAt.timeIntervalSince1970 * 1000),
            "lastModified": Int((receipt.updatedAt ?? Date()).timeIntervalSince1970 * 1000),
            "title": receipt.title,
            "place": receipt.storeName,
            "locationAddress": receipt.address,
            "customerName": receipt.customerName,
            "customerPhone": receipt.customerPhone,
            "customerEmail": receipt.customerEmail,
            "customerAddress": receipt.customerAddress,
            "currency": receipt.currencyCode,
            "category": displayCase(receipt.categoryRaw),
            "paymentType": displayCase(receipt.paymentMethodRaw),
            "discountType": displayCase(receipt.discountTypeRaw),
            "discountValue": receipt.discountValue.doubleValue,
            "taxPercentage": receipt.taxPercent.doubleValue,
            "cashGiven": receipt.cashGiven.doubleValue,
            "changeAmount": NSDecimalNumber(decimal: totals.change).doubleValue,
            "subtotal": NSDecimalNumber(decimal: totals.subtotal).doubleValue,
            "grandTotal": NSDecimalNumber(decimal: totals.grandTotal).doubleValue,
            "note": receipt.note,
            "notePage2": receipt.notesPageTwo,
            "accountName": receipt.issuedByName,
            "accountEmail": receipt.issuedByEmail,
            "items": receipt.orderedItems.map { item in
                [
                    "name": item.name,
                    "quantity": Double(item.quantity),
                    "totalPrice": item.unitPrice
                        .multiplying(by: NSDecimalNumber(value: Int(item.quantity)))
                        .doubleValue
                ] as [String: Any]
            }
        ]

        // iOS-only fields. Android ignores keys it does not know, and carrying
        // them means a memo written here survives the round trip with its
        // identity and archive state intact instead of being rebuilt as new.
        document["uuid"] = receipt.id.uuidString
        document["isArchived"] = receipt.isArchived
        if let markup = receipt.markupJSON, !markup.isEmpty {
            document["markupJSON"] = markup
        }
        if let memberID = receipt.memberID { document["memberID"] = memberID.uuidString }

        if let latitude = receipt.latitude?.doubleValue { document["latitude"] = latitude }
        if let longitude = receipt.longitude?.doubleValue { document["longitude"] = longitude }
        if let signature = receipt.signaturePNG,
           signature.count <= ReceiptDocument.maxSignatureBytes {
            document["signatureBase64"] = signature.base64EncodedString()
        }

        return document
    }

    // MARK: - Enum translation

    /// Android stores display text — "Bills", "Cash", "None". iOS stores raw
    /// values — "utilities", "cash", "none". Matching is case-insensitive, with a
    /// short alias table for the names that do not simply lower-case across.
    private static let categoryAliases: [String: ReceiptCategory] = [
        "bills": .utilities,
        "grocery": .groceries,
        "medical": .health,
        "transport": .travel,
        "fuel": .fuel
    ]

    static func category(_ raw: String) -> String {
        let key = raw.lowercased()
        if let alias = categoryAliases[key] { return alias.rawValue }
        if let match = ReceiptCategory.allCases.first(where: { $0.rawValue.lowercased() == key }) {
            return match.rawValue
        }
        return ReceiptCategory.other.rawValue
    }

    private static let paymentAliases: [String: PaymentMethod] = [
        "apple pay": .applePay,
        "bank transfer": .bankTransfer,
        "banktransfer": .bankTransfer,
        "easy paisa": .easypaisa,
        "jazz cash": .jazzcash
    ]

    static func paymentMethod(_ raw: String) -> String {
        let key = raw.lowercased()
        if let alias = paymentAliases[key] { return alias.rawValue }
        if let match = PaymentMethod.allCases.first(where: { $0.rawValue.lowercased() == key }) {
            return match.rawValue
        }
        return PaymentMethod.cash.rawValue
    }

    static func discountType(_ raw: String) -> String {
        let key = raw.lowercased()
        if key.hasPrefix("percent") { return DiscountType.percentage.rawValue }
        if key.hasPrefix("fixed") { return DiscountType.fixed.rawValue }
        return DiscountType.none.rawValue
    }

    /// "bankTransfer" → "Bank Transfer", the shape Android writes.
    private static func displayCase(_ raw: String) -> String {
        var words: [String] = []
        var current = ""
        for character in raw {
            if character.isUppercase && !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: - Coercion

    private static func string(_ value: Any?, fallback: String = "") -> String {
        (value as? String) ?? fallback
    }

    private static func numberValue(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func numberText(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        guard let number = value as? NSNumber else { return nil }
        return String(number.intValue)
    }

    private static func decimal(_ value: Any?) -> NSDecimalNumber {
        guard let number = value as? NSNumber else { return .zero }
        // Through NSNumber's string form rather than its double: going via
        // Decimal(double:) reintroduces the binary rounding the strings avoid.
        let parsed = NSDecimalNumber(string: number.stringValue)
        return parsed == NSDecimalNumber.notANumber ? .zero : parsed
    }

    /// Android writes epoch milliseconds as an integer. Anything past the year
    /// 5000 in seconds is milliseconds — real receipt dates are nowhere near it.
    static func date(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return ReceiptDocument.date(value) }
        let raw = number.doubleValue
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw > 100_000_000_000 ? raw / 1000 : raw)
    }
}
