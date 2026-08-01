import CoreData
import Foundation
import UniformTypeIdentifiers

/// JSON export/import of the whole store.
///
/// Plain JSON rather than a copy of the SQLite file, so a backup taken on one
/// device restores cleanly onto another even after a schema migration.
enum BackupArchive {
    struct Payload: Codable {
        var version: Int = 1
        var exportedAt: Date
        var receipts: [ReceiptPayload]
        var members: [MemberPayload]
    }

    struct ReceiptPayload: Codable {
        var id: UUID
        var number: String
        var createdAt: Date
        var title: String
        var storeName: String
        var address: String
        var latitude: Double?
        var longitude: Double?
        var memberID: UUID?
        var customerName: String
        var customerPhone: String
        var customerEmail: String
        var currencyCode: String
        var category: String
        var paymentMethod: String
        var discountType: String
        var discountValue: String
        var taxPercent: String
        var cashGiven: String
        var note: String
        var notesPageTwo: String
        var signaturePNG: Data?
        var isArchived: Bool
        var issuedByName: String?
        var issuedByEmail: String?
        var items: [ItemPayload]
    }

    struct ItemPayload: Codable {
        var id: UUID
        var name: String
        var quantity: Int
        var unitPrice: String
        var sortIndex: Int
    }

    struct MemberPayload: Codable {
        var id: UUID
        var name: String
        var phone: String
        var email: String
        var notes: String
        var createdAt: Date
        var avatarPNG: Data?
    }

    // MARK: - Export

    static func export(context: NSManagedObjectContext) throws -> URL {
        let receipts = try context.fetch(CDReceipt.fetchRequest())
        let members = try context.fetch(CDMember.allRequest())

        let payload = Payload(
            exportedAt: Date(),
            receipts: receipts.map(encode(receipt:)),
            members: members.map(encode(member:))
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CashMemer-Backup-\(stamp)")
            .appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func encode(receipt: CDReceipt) -> ReceiptPayload {
        ReceiptPayload(
            id: receipt.id,
            number: receipt.number,
            createdAt: receipt.createdAt,
            title: receipt.title,
            storeName: receipt.storeName,
            address: receipt.address,
            latitude: receipt.latitude?.doubleValue,
            longitude: receipt.longitude?.doubleValue,
            memberID: receipt.memberID,
            customerName: receipt.customerName,
            customerPhone: receipt.customerPhone,
            customerEmail: receipt.customerEmail,
            currencyCode: receipt.currencyCode,
            category: receipt.categoryRaw,
            paymentMethod: receipt.paymentMethodRaw,
            discountType: receipt.discountTypeRaw,
            // Decimals travel as strings so no cent is lost to binary floating point.
            discountValue: receipt.discountValue.stringValue,
            taxPercent: receipt.taxPercent.stringValue,
            cashGiven: receipt.cashGiven.stringValue,
            note: receipt.note,
            notesPageTwo: receipt.notesPageTwo,
            signaturePNG: receipt.signaturePNG,
            isArchived: receipt.isArchived,
            issuedByName: receipt.issuedByName,
            issuedByEmail: receipt.issuedByEmail,
            items: receipt.orderedItems.map {
                ItemPayload(
                    id: $0.id,
                    name: $0.name,
                    quantity: Int($0.quantity),
                    unitPrice: $0.unitPrice.stringValue,
                    sortIndex: Int($0.sortIndex)
                )
            }
        )
    }

    private static func encode(member: CDMember) -> MemberPayload {
        MemberPayload(
            id: member.id,
            name: member.name,
            phone: member.phone,
            email: member.email,
            notes: member.notes,
            createdAt: member.createdAt,
            avatarPNG: member.avatarPNG
        )
    }

    // MARK: - Import

    /// Restores a backup, skipping anything already present so a restore can be
    /// run twice without creating duplicates.
    @discardableResult
    static func restore(from url: URL, into context: NSManagedObjectContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(Payload.self, from: Data(contentsOf: url))

        var restored = 0

        for member in payload.members where !exists(id: member.id, entity: "CDMember", context: context) {
            let object = CDMember(context: context)
            object.id = member.id
            object.name = member.name
            object.phone = member.phone
            object.email = member.email
            object.notes = member.notes
            object.createdAt = member.createdAt
            object.avatarPNG = member.avatarPNG
        }

        for receipt in payload.receipts where !exists(id: receipt.id, entity: "CDReceipt", context: context) {
            let object = CDReceipt(context: context)
            object.id = receipt.id
            object.number = receipt.number
            object.createdAt = receipt.createdAt
            object.title = receipt.title
            object.storeName = receipt.storeName
            object.address = receipt.address
            object.latitude = receipt.latitude.map { NSNumber(value: $0) }
            object.longitude = receipt.longitude.map { NSNumber(value: $0) }
            object.memberID = receipt.memberID
            object.customerName = receipt.customerName
            object.customerPhone = receipt.customerPhone
            object.customerEmail = receipt.customerEmail
            object.currencyCode = receipt.currencyCode
            object.categoryRaw = receipt.category
            object.paymentMethodRaw = receipt.paymentMethod
            object.discountTypeRaw = receipt.discountType
            object.discountValue = NSDecimalNumber(string: receipt.discountValue)
            object.taxPercent = NSDecimalNumber(string: receipt.taxPercent)
            object.cashGiven = NSDecimalNumber(string: receipt.cashGiven)
            object.note = receipt.note
            object.notesPageTwo = receipt.notesPageTwo
            object.signaturePNG = receipt.signaturePNG
            object.isArchived = receipt.isArchived
            object.issuedByName = receipt.issuedByName ?? ""
            object.issuedByEmail = receipt.issuedByEmail ?? ""

            for item in receipt.items {
                let line = CDReceiptItem(context: context)
                line.id = item.id
                line.name = item.name
                line.quantity = Int32(item.quantity)
                line.unitPrice = NSDecimalNumber(string: item.unitPrice)
                line.sortIndex = Int32(item.sortIndex)
                line.receipt = object
            }
            restored += 1
        }

        try context.save()
        return restored
    }

    private static func exists(id: UUID, entity: String, context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }
}
