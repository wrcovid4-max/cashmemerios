import Foundation

struct RevenueBucket: Identifiable {
    let date: Date
    let total: Decimal

    var id: Date { date }
    var doubleTotal: Double { NSDecimalNumber(decimal: total).doubleValue }
}

/// Aggregates a set of receipts into the numbers the Dashboard tiles and Insights
/// card display. Pure value logic so it can be unit-tested without Core Data.
struct DashboardMetrics {
    let count: Int
    let total: Decimal
    let itemCount: Int
    let topStore: String?
    let topCategory: ReceiptCategory?
    let topPaymentMethod: PaymentMethod?
    let largest: Decimal

    init(receipts: [CDReceipt]) {
        count = receipts.count
        total = receipts.reduce(Decimal.zero) { $0 + $1.totals.grandTotal }
        itemCount = receipts.reduce(0) { $0 + $1.orderedItems.reduce(0) { $0 + Int($1.quantity) } }
        largest = receipts.map { $0.totals.grandTotal }.max() ?? 0

        topStore = Self.mostFrequent(
            receipts.map { $0.storeName.isEmpty ? $0.title : $0.storeName }.filter { !$0.isEmpty }
        )
        topCategory = Self.mostFrequent(receipts.map { $0.category })
        topPaymentMethod = Self.mostFrequent(receipts.map { $0.paymentMethod })
    }

    var average: Decimal {
        guard count > 0 else { return 0 }
        return (total / Decimal(count)).rounded(2)
    }

    /// Short plain-language observations, only produced once there is enough data
    /// to say something that is not obvious from the tiles.
    func insights(currency: Currency) -> [String] {
        guard count >= 3 else { return [] }

        var lines: [String] = []
        if let topStore = topStore {
            lines.append("\(topStore) is your most frequent store this period.")
        }
        if let topCategory = topCategory {
            lines.append("Most receipts fall under \(topCategory.rawValue.capitalized).")
        }
        if let method = topPaymentMethod {
            lines.append("\(method.rawValue.capitalized) is the most used payment method.")
        }
        if largest > 0 {
            lines.append("Largest single receipt: \(CurrencyFormatter.string(largest, currency: currency)).")
        }
        lines.append("Average receipt is \(CurrencyFormatter.string(average, currency: currency)) across \(count) memos.")
        return lines
    }

    private static func mostFrequent<T: Hashable>(_ values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        var counts: [T: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Groups receipts into chart buckets, collapsing each to the start of its
    /// hour/day/month so the axis has one point per interval.
    static func buckets(
        for receipts: [CDReceipt],
        component: Calendar.Component,
        calendar: Calendar = .current
    ) -> [RevenueBucket] {
        guard !receipts.isEmpty else { return [] }

        var totals: [Date: Decimal] = [:]
        for receipt in receipts {
            guard let start = calendar.dateInterval(of: component, for: receipt.createdAt)?.start else { continue }
            totals[start, default: 0] += receipt.totals.grandTotal
        }

        return totals
            .map { RevenueBucket(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
