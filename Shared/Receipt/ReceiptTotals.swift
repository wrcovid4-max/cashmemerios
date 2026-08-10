import Foundation

/// Pure arithmetic for a memo, kept out of the Core Data entity so the live preview
/// can total an in-progress form that has not been persisted yet.
struct ReceiptTotals: Equatable {
    let subtotal: Decimal
    let discount: Decimal
    let tax: Decimal
    let grandTotal: Decimal
    let cashGiven: Decimal
    let change: Decimal

    /// What the memo would have come to with no discount applied.
    ///
    /// Tax is recomputed on the full subtotal rather than reusing `tax`, because
    /// the real tax is charged on the discounted base — carrying it over would
    /// quietly understate the undiscounted figure and make the saving look
    /// larger than it is.
    let totalWithoutDiscount: Decimal

    /// What the memo comes to before tax: subtotal less discount. This is the
    /// same figure the tax is charged on.
    let totalWithoutTax: Decimal

    init(
        items: [(quantity: Int, unitPrice: Decimal)],
        discountType: DiscountType,
        discountValue: Decimal,
        taxPercent: Decimal,
        cashGiven: Decimal
    ) {
        let subtotal = items.reduce(Decimal.zero) { $0 + $1.unitPrice * Decimal($1.quantity) }

        let discount: Decimal
        switch discountType {
        case .none: discount = 0
        case .percentage: discount = (subtotal * discountValue / 100).rounded(2)
        case .fixed: discount = discountValue
        }
        // A discount is never allowed to push the memo negative.
        let cappedDiscount = min(max(discount, 0), subtotal)

        let taxable = subtotal - cappedDiscount
        let tax = (taxable * taxPercent / 100).rounded(2)
        let grandTotal = (taxable + tax).rounded(2)

        self.subtotal = subtotal.rounded(2)
        self.discount = cappedDiscount.rounded(2)
        self.tax = tax
        self.grandTotal = grandTotal
        self.cashGiven = cashGiven.rounded(2)
        // Change is only meaningful once the customer has handed over at least the total.
        self.change = max(cashGiven - grandTotal, 0).rounded(2)

        let taxOnFullSubtotal = (subtotal * taxPercent / 100).rounded(2)
        self.totalWithoutDiscount = (subtotal + taxOnFullSubtotal).rounded(2)
        self.totalWithoutTax = taxable.rounded(2)
    }
}

extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var source = self
        var result = Decimal.zero
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
