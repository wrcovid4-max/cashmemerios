import Combine
import CoreData
import Foundation

/// Mutable state for the New Receipt form.
///
/// Kept separate from the Core Data entity so the live preview can render an
/// in-progress form that has never been written to the store. Every field is
/// `@Published` because the iPad preview pane redraws on each keystroke.
final class ReceiptDraft: ObservableObject {
    /// Assigned from the store when the form appears, so it is the next number
    /// in the book rather than a random one.
    @Published var number = "1"
    @Published var createdAt = Date()

    @Published var title = ""
    @Published var storeName = ""
    @Published var address = ""
    @Published var latitude: Double?
    @Published var longitude: Double?

    @Published var memberID: UUID?
    @Published var customerName = ""
    @Published var customerPhone = ""
    @Published var customerEmail = ""
    @Published var customerAddress = ""

    @Published var currency: Currency = .pkr
    @Published var category: ReceiptCategory = .shopping
    @Published var paymentMethod: PaymentMethod = .cash

    @Published var lines: [DraftLine] = []

    @Published var discountType: DiscountType = .none
    @Published var discountValueText = ""
    /// Typing a tax percentage by hand means the per-tax lines no longer match it, so they go.
    @Published var taxPercentText = "" {
        didSet { if taxPercentText != oldValue { taxLines = [] } }
    }
    @Published var cashGivenText = ""
    @Published var extraFeesText = ""
    /// Each tax from a scan, shown on the memo when the per-tax setting is on.
    @Published var taxLines: [MemoTaxLine] = []

    /// Pre-filled with `MemoDefaults.noteOne`; edit or clear it freely.
    @Published var note = MemoDefaults.noteOne
    /// Private note printed on page 2 only. Deliberately left empty.
    @Published var notesPageTwo = ""
    @Published var issuedByName = ""
    @Published var issuedByEmail = ""
    @Published var signaturePNG: Data?
    @Published var saveSignatureAsDefault = true

    struct DraftLine: Identifiable, Equatable {
        var id = UUID()
        var name: String
        var quantity: Int
        var unitPrice: Decimal
    }

    // MARK: - Derived

    var discountValue: Decimal { Decimal(string: discountValueText) ?? 0 }
    var taxPercent: Decimal { Decimal(string: taxPercentText) ?? 0 }
    var cashGiven: Decimal { Decimal(string: cashGivenText) ?? 0 }
    var extraFees: Decimal { Decimal(string: extraFeesText) ?? 0 }

    var totals: ReceiptTotals {
        ReceiptTotals(
            items: lines.map { (quantity: $0.quantity, unitPrice: $0.unitPrice) },
            discountType: discountType,
            discountValue: discountValue,
            taxPercent: taxPercent,
            cashGiven: cashGiven,
            extraFees: extraFees
        )
    }

    /// A receipt needs somewhere it came from and at least one line to be worth saving.
    var canGenerate: Bool {
        !lines.isEmpty && !(title.isEmpty && storeName.isEmpty)
    }

    var snapshot: MemoSnapshot {
        MemoSnapshot(
            id: draftID,
            number: number,
            createdAt: createdAt,
            title: title,
            storeName: storeName,
            address: address,
            coordinateText: coordinateText,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
            customerAddress: customerAddress,
            category: category,
            paymentMethod: paymentMethod,
            currency: currency,
            lines: lines.map {
                MemoSnapshot.Line(id: $0.id, name: $0.name, quantity: $0.quantity, unitPrice: $0.unitPrice)
            },
            totals: totals,
            taxPercent: taxPercent,
            taxLines: taxLines,
            note: note,
            notesPageTwo: notesPageTwo,
            issuedByName: issuedByName,
            issuedByEmail: issuedByEmail,
            signaturePNG: signaturePNG
        )
    }

    private let draftID = UUID()

    private var coordinateText: String? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    // MARK: - Mutation

    func addLine(name: String, quantity: Int, unitPrice: Decimal) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lines.append(DraftLine(name: trimmed, quantity: max(quantity, 1), unitPrice: unitPrice))
    }

    func removeLines(at offsets: IndexSet) {
        lines.remove(atOffsets: offsets)
    }

    func apply(_ member: CDMember) {
        memberID = member.id
        customerName = member.name
        customerPhone = member.phone
        customerEmail = member.email
        // A member has no address field, so whatever was typed here is left alone.
    }

    /// Merges an OCR result into the form, leaving anything the user already typed alone.
    func apply(_ scan: ScannedReceipt, settings: AppSettings) {
        if storeName.isEmpty, let store = scan.storeName { storeName = store }
        if title.isEmpty, let store = scan.storeName { title = store }
        if address.isEmpty, let scanned = scan.address { address = scanned }
        if let date = scan.date { createdAt = date }
        if let category = scan.category { self.category = category }
        if let method = scan.paymentMethod { paymentMethod = method }
        if let code = scan.currencyCode,
           let matched = settings.availableCurrencies.first(where: { $0.code == code }) {
            currency = matched
        }
        if !scan.taxes.isEmpty {
            // Set the percentage first: changing it clears the lines, so the lines go in last.
            if taxPercentText.isEmpty {
                let sum = scan.taxes.reduce(Decimal.zero) { $0 + $1.percent }
                if sum > 0 { taxPercentText = "\(sum)" }
            }
            taxLines = settings.showTaxBreakdown
                ? scan.taxes.map { MemoTaxLine(name: $0.name, percent: $0.percent) }
                : []
        }
        if let fees = scan.extraFees, fees > 0, settings.includeScanFees {
            extraFeesText = "\(fees)"
        }
        if let tax = scan.taxPercent, taxPercentText.isEmpty, tax > 0 {
            taxPercentText = "\(tax)"
        }
        for line in scan.lines {
            addLine(name: line.name, quantity: line.quantity, unitPrice: line.unitPrice)
        }
        // Some receipts only print a total; record it as a single line so the memo balances.
        if scan.lines.isEmpty, let total = scan.total, total > 0 {
            addLine(name: scan.storeName ?? "Item", quantity: 1, unitPrice: total)
        }
    }

    /// Clears the form for the next memo.
    ///
    /// The captured location and the signature are deliberately left alone: both
    /// are laborious to redo and almost always still correct for the next receipt
    /// written in the same place by the same person. `clearAll` takes them too.
    func reset(defaultCurrency: Currency, nextNumber: String, clearAll: Bool = false) {
        number = nextNumber
        createdAt = Date()
        title = ""
        storeName = ""
        if clearAll {
            address = ""
            latitude = nil
            longitude = nil
            signaturePNG = nil
        }
        memberID = nil
        customerName = ""
        customerPhone = ""
        customerEmail = ""
        customerAddress = ""
        currency = defaultCurrency
        category = .shopping
        paymentMethod = .cash
        lines = []
        discountType = .none
        discountValueText = ""
        extraFeesText = ""
        taxLines = []
        taxPercentText = ""
        cashGivenText = ""
        note = MemoDefaults.noteOne
        notesPageTwo = ""
    }

    /// Stamps the signed-in Google account onto the draft so page 2 records who
    /// issued the memo even if the account is signed out later.
    /// Pre-fills both footers from Settings. A locked footer always takes the Settings
    /// value; an unlocked one is only replaced while it is still empty or untouched.
    func adoptFooters(from settings: AppSettings) {
        if settings.lockFooterOne || note.isEmpty || note == MemoDefaults.noteOne {
            note = settings.footerOneDefault
        }
        if settings.lockFooterTwo || notesPageTwo.isEmpty {
            notesPageTwo = settings.footerTwoDefault
        }
    }

    func adoptIssuer(from settings: AppSettings) {
        adoptFooters(from: settings)
        issuedByName = settings.googleAccountName ?? ""
        issuedByEmail = settings.googleAccountEmail ?? ""
    }

    /// Materialises the draft into Core Data and returns the saved receipt.
    @discardableResult
    func persist(in context: NSManagedObjectContext) throws -> CDReceipt {
        let receipt = CDReceipt(context: context)
        receipt.id = UUID()
        receipt.number = number
        receipt.createdAt = createdAt
        receipt.title = title
        receipt.storeName = storeName
        receipt.address = address
        receipt.latitude = latitude.map { NSNumber(value: $0) }
        receipt.longitude = longitude.map { NSNumber(value: $0) }
        receipt.memberID = memberID
        receipt.customerName = customerName
        receipt.customerPhone = customerPhone
        receipt.customerEmail = customerEmail
        receipt.customerAddress = customerAddress
        receipt.currencyCode = currency.code
        receipt.categoryRaw = category.rawValue
        receipt.paymentMethodRaw = paymentMethod.rawValue
        receipt.discountTypeRaw = discountType.rawValue
        receipt.discountValue = NSDecimalNumber(decimal: discountValue)
        receipt.taxPercent = NSDecimalNumber(decimal: taxPercent)
        receipt.cashGiven = NSDecimalNumber(decimal: cashGiven)
        receipt.extraFees = NSDecimalNumber(decimal: extraFees)
        receipt.taxBreakdownJSON = MemoTaxLine.encode(taxLines)
        receipt.note = note
        receipt.notesPageTwo = notesPageTwo
        receipt.signaturePNG = signaturePNG
        receipt.isArchived = false
        receipt.issuedByName = issuedByName
        receipt.issuedByEmail = issuedByEmail

        for (index, line) in lines.enumerated() {
            let item = CDReceiptItem(context: context)
            item.id = line.id
            item.name = line.name
            item.quantity = Int32(line.quantity)
            item.unitPrice = NSDecimalNumber(decimal: line.unitPrice)
            item.sortIndex = Int32(index)
            item.receipt = receipt
        }

        try context.save()
        return receipt
    }
}
