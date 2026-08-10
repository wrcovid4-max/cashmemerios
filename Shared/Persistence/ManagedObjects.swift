import CoreData
import Foundation

// Codegen for the model is set to Manual/None; these subclasses are the only
// definitions, which keeps the domain helpers next to the stored properties.

@objc(CDReceipt)
public final class CDReceipt: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var number: String
    @NSManaged public var createdAt: Date
    @NSManaged public var title: String
    @NSManaged public var storeName: String
    @NSManaged public var address: String
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var memberID: UUID?
    @NSManaged public var customerName: String
    @NSManaged public var customerPhone: String
    @NSManaged public var customerEmail: String
    /// The customer's own address — printed on page 2 only, separate from
    /// `address`, which is the GPS-captured transaction location.
    @NSManaged public var customerAddress: String
    @NSManaged public var currencyCode: String
    @NSManaged public var categoryRaw: String
    @NSManaged public var paymentMethodRaw: String
    @NSManaged public var discountTypeRaw: String
    @NSManaged public var discountValue: NSDecimalNumber
    @NSManaged public var taxPercent: NSDecimalNumber
    @NSManaged public var cashGiven: NSDecimalNumber
    @NSManaged public var note: String
    @NSManaged public var notesPageTwo: String
    @NSManaged public var signaturePNG: Data?
    @NSManaged public var isArchived: Bool
    /// Google account that issued the memo — printed on page 2 only.
    @NSManaged public var issuedByName: String
    @NSManaged public var issuedByEmail: String
    /// Last local edit, compared against the remote copy to settle conflicts.
    @NSManaged public var updatedAt: Date?
    @NSManaged public var items: NSSet?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDReceipt> {
        NSFetchRequest<CDReceipt>(entityName: "CDReceipt")
    }
}

extension CDReceipt: Identifiable {
    /// Line items in printed order.
    public var orderedItems: [CDReceiptItem] {
        let all = (items as? Set<CDReceiptItem>) ?? []
        return all.sorted { $0.sortIndex < $1.sortIndex }
    }

    var category: ReceiptCategory {
        get { ReceiptCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .cash }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var discountType: DiscountType {
        get { DiscountType(rawValue: discountTypeRaw) ?? .none }
        set { discountTypeRaw = newValue.rawValue }
    }

    var currency: Currency {
        Currency.builtIn(code: currencyCode)
            ?? Currency(code: currencyCode, symbol: currencyCode, name: currencyCode)
    }

    var coordinateText: String? {
        guard let latitude = latitude?.doubleValue, let longitude = longitude?.doubleValue else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    var totals: ReceiptTotals {
        ReceiptTotals(
            items: orderedItems.map { (quantity: Int($0.quantity), unitPrice: $0.unitPrice as Decimal) },
            discountType: discountType,
            discountValue: discountValue as Decimal,
            taxPercent: taxPercent as Decimal,
            cashGiven: cashGiven as Decimal
        )
    }

    /// `#41` — the form the memo and the exported filename both use.
    var displayNumber: String { "#\(number)" }

    /// Receipts are numbered sequentially like a paper book, so the next number is
    /// one past the highest already issued.
    static func nextNumber(in context: NSManagedObjectContext) -> String {
        let request = CDReceipt.fetchRequest()
        request.propertiesToFetch = ["number"]
        let existing = (try? context.fetch(request)) ?? []
        let highest = existing.compactMap { Int($0.number) }.max() ?? 0
        return String(highest + 1)
    }
}

@objc(CDReceiptItem)
public final class CDReceiptItem: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var quantity: Int32
    @NSManaged public var unitPrice: NSDecimalNumber
    @NSManaged public var sortIndex: Int32
    @NSManaged public var receipt: CDReceipt?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDReceiptItem> {
        NSFetchRequest<CDReceiptItem>(entityName: "CDReceiptItem")
    }
}

extension CDReceiptItem: Identifiable {
    var lineTotal: Decimal { (unitPrice as Decimal) * Decimal(quantity) }
}

@objc(CDMember)
public final class CDMember: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var phone: String
    @NSManaged public var email: String
    @NSManaged public var notes: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date?
    @NSManaged public var avatarPNG: Data?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMember> {
        NSFetchRequest<CDMember>(entityName: "CDMember")
    }
}

extension CDMember: Identifiable {
    /// Initials shown when a member has no avatar image.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    /// CSV row for the directory export button.
    var csvRow: String {
        [name, phone, email, notes]
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: ",")
    }

    static let csvHeader = "Name,Phone,Email,Notes"
}
