import Foundation
import SwiftData

@Model
final class Receipt {
    /// Stable identity used by sync payloads and the QR code deep link.
    @Attribute(.unique) var id: UUID
    /// Human-facing reference printed on the memo, e.g. `84AC83A`.
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
    var categoryRaw: String
    var paymentMethodRaw: String

    var discountTypeRaw: String
    var discountValue: Decimal
    var taxPercent: Decimal
    var cashGiven: Decimal

    var note: String
    var notesPageTwo: String
    @Attribute(.externalStorage) var signaturePNG: Data?

    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt)
    var items: [ReceiptItem]

    init(
        id: UUID = UUID(),
        number: String = Receipt.generateNumber(),
        createdAt: Date = .now,
        title: String = "",
        storeName: String = "",
        address: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        memberID: UUID? = nil,
        customerName: String = "",
        customerPhone: String = "",
        customerEmail: String = "",
        currencyCode: String = Currency.pkr.code,
        category: ReceiptCategory = .shopping,
        paymentMethod: PaymentMethod = .cash,
        discountType: DiscountType = .none,
        discountValue: Decimal = 0,
        taxPercent: Decimal = 0,
        cashGiven: Decimal = 0,
        note: String = "",
        notesPageTwo: String = "",
        signaturePNG: Data? = nil,
        isArchived: Bool = false,
        items: [ReceiptItem] = []
    ) {
        self.id = id
        self.number = number
        self.createdAt = createdAt
        self.title = title
        self.storeName = storeName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.memberID = memberID
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerEmail = customerEmail
        self.currencyCode = currencyCode
        self.categoryRaw = category.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.discountTypeRaw = discountType.rawValue
        self.discountValue = discountValue
        self.taxPercent = taxPercent
        self.cashGiven = cashGiven
        self.note = note
        self.notesPageTwo = notesPageTwo
        self.signaturePNG = signaturePNG
        self.isArchived = isArchived
        self.items = items
    }

    /// Seven uppercase hex characters, matching the `84AC83A` format on the memo.
    static func generateNumber() -> String {
        String((0..<7).map { _ in "0123456789ABCDEF".randomElement()! })
    }
}

extension Receipt {
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
        Currency.builtIn(code: currencyCode) ?? Currency(code: currencyCode, symbol: currencyCode, name: currencyCode)
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// `31.464347, 74.390228` — the coordinate line under "Saved Location".
    var coordinateText: String? {
        guard let latitude, let longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    var totals: ReceiptTotals {
        ReceiptTotals(
            items: items.map { (quantity: $0.quantity, unitPrice: $0.unitPrice) },
            discountType: discountType,
            discountValue: discountValue,
            taxPercent: taxPercent,
            cashGiven: cashGiven
        )
    }
}
