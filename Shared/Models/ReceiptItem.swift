import Foundation
import SwiftData

@Model
final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    /// Position in the printed item table; kept explicit so reordering survives a fetch.
    var sortIndex: Int
    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        unitPrice: Decimal = 0,
        sortIndex: Int = 0,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.sortIndex = sortIndex
        self.receipt = receipt
    }

    var lineTotal: Decimal { unitPrice * Decimal(quantity) }
}
