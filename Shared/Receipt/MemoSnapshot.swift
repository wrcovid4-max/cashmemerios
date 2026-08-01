import Foundation

/// An immutable value describing everything printed on a memo.
///
/// Both the persisted `Receipt` and the in-progress New Receipt form project into
/// this type, which is what lets the iPad live preview render an unsaved form with
/// exactly the same code that exports the final PDF.
struct MemoSnapshot: Equatable {
    var id: UUID
    var number: String
    var createdAt: Date
    var title: String
    var storeName: String
    var address: String
    var coordinateText: String?
    var customerName: String
    var customerPhone: String
    var customerEmail: String
    var category: ReceiptCategory
    var paymentMethod: PaymentMethod
    var currency: Currency
    var lines: [Line]
    var totals: ReceiptTotals
    var note: String
    var notesPageTwo: String
    var signaturePNG: Data?

    struct Line: Equatable, Identifiable {
        var id: UUID
        var name: String
        var quantity: Int
        var unitPrice: Decimal
        var total: Decimal { unitPrice * Decimal(quantity) }
    }

    var dateText: String { Self.dateFormatter.string(from: createdAt) }
    var timeText: String { Self.timeFormatter.string(from: createdAt) }

    /// Header line under CASH MEMO — the store, falling back to the title.
    var headerSubtitle: String {
        let store = storeName.trimmingCharacters(in: .whitespaces)
        return store.isEmpty ? title.trimmingCharacters(in: .whitespaces) : store
    }

    var hasCashDetails: Bool { totals.cashGiven > 0 }

    /// Payload encoded into the memo's QR code.
    var qrPayload: String {
        var components = URLComponents()
        components.scheme = "cashmemer"
        components.host = "receipt"
        components.path = "/\(number)"
        components.queryItems = [
            URLQueryItem(name: "id", value: id.uuidString),
            URLQueryItem(name: "total", value: "\(totals.grandTotal)"),
            URLQueryItem(name: "currency", value: currency.code),
            URLQueryItem(name: "date", value: ISO8601DateFormatter().string(from: createdAt))
        ]
        return components.url?.absoluteString ?? number
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

extension MemoSnapshot {
    init(receipt: CDReceipt) {
        self.init(
            id: receipt.id,
            number: receipt.number,
            createdAt: receipt.createdAt,
            title: receipt.title,
            storeName: receipt.storeName,
            address: receipt.address,
            coordinateText: receipt.coordinateText,
            customerName: receipt.customerName,
            customerPhone: receipt.customerPhone,
            customerEmail: receipt.customerEmail,
            category: receipt.category,
            paymentMethod: receipt.paymentMethod,
            currency: receipt.currency,
            lines: receipt.orderedItems.map {
                Line(id: $0.id, name: $0.name, quantity: Int($0.quantity), unitPrice: $0.unitPrice as Decimal)
            },
            totals: receipt.totals,
            note: receipt.note,
            notesPageTwo: receipt.notesPageTwo,
            signaturePNG: receipt.signaturePNG
        )
    }
}
