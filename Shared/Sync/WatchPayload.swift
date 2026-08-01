import Foundation

/// Lightweight receipt summaries pushed to the watch.
///
/// The watch shows History and Dashboard only, so it never needs line items,
/// signatures or addresses — sending just these fields keeps the transfer inside
/// WatchConnectivity's application-context size budget.
struct WatchPayload: Codable, Equatable {
    var generatedAt: Date
    var currencySymbol: String
    var receipts: [Summary]

    struct Summary: Codable, Equatable, Identifiable {
        var id: UUID
        var number: String
        var store: String
        var total: Double
        var date: Date
        var categoryRaw: String
        var paymentRaw: String

        var category: ReceiptCategory { ReceiptCategory(rawValue: categoryRaw) ?? .other }
        var paymentMethod: PaymentMethod { PaymentMethod(rawValue: paymentRaw) ?? .cash }
    }

    static let empty = WatchPayload(generatedAt: .distantPast, currencySymbol: "Rs", receipts: [])

    /// Today's receipts and their total — the watch Dashboard.
    func todaysTotals(calendar: Calendar = .current) -> (count: Int, total: Double) {
        let todays = receipts.filter { calendar.isDateInToday($0.date) }
        return (todays.count, todays.reduce(0) { $0 + $1.total })
    }

    var weekTotal: Double {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return receipts
            .filter { interval.contains($0.date) }
            .reduce(0) { $0 + $1.total }
    }

    /// Newest first, capped so the watch list stays snappy.
    func recent(limit: Int = 25) -> [Summary] {
        Array(receipts.sorted { $0.date > $1.date }.prefix(limit))
    }
}
