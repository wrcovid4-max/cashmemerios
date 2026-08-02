import Foundation

/// A currency the app can price receipts in. The built-in set matches the Android
/// build's picker; users can append their own from Settings → Custom Currency.
struct Currency: Codable, Hashable, Identifiable {
    var code: String
    var symbol: String
    var name: String

    var id: String { code }

    static let pkr = Currency(code: "PKR", symbol: "Rs", name: "Pakistani Rupee")

    static let builtIn: [Currency] = [
        .pkr,
        Currency(code: "USD", symbol: "$", name: "US Dollar"),
        Currency(code: "EUR", symbol: "€", name: "Euro"),
        Currency(code: "GBP", symbol: "£", name: "British Pound"),
        Currency(code: "SAR", symbol: "﷼", name: "Saudi Riyal"),
        Currency(code: "AED", symbol: "د.إ", name: "UAE Dirham"),
        Currency(code: "CNY", symbol: "¥", name: "Chinese Yuan"),
        Currency(code: "IRR", symbol: "﷼", name: "Iranian Rial"),
        Currency(code: "RUB", symbol: "₽", name: "Russian Ruble"),
        Currency(code: "TMN", symbol: "T", name: "Iranian Toman"),
        Currency(code: "INR", symbol: "₹", name: "Indian Rupee"),
        Currency(code: "TRY", symbol: "₺", name: "Turkish Lira")
    ]

    static func builtIn(code: String) -> Currency? {
        builtIn.first { $0.code == code }
    }

    /// "Pakistani Rupee (Rs)" — the label shape used by the Currency picker row.
    var pickerLabel: String { "\(name) (\(symbol))" }
}

enum CurrencyFormatter {
    /// Receipts render amounts as `Rs 350.00` — symbol, space, two decimals, grouped.
    static func string(_ amount: Decimal, currency: Currency, locale: Locale = Locale(identifier: "en_US")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(currency.symbol) \(number)"
    }

    /// `Rs12.00` — no space, as printed on the memo's per-unit sub-line.
    static func tight(_ amount: Decimal, currency: Currency) -> String {
        string(amount, currency: currency).replacingOccurrences(of: " ", with: "")
    }

    /// Compact form for stat tiles, where space is tight: `Rs 12.4K`.
    static func compact(_ amount: Decimal, currency: Currency) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let magnitude = abs(value)
        let scaled: Double
        let suffix: String
        switch magnitude {
        case 1_000_000...:
            scaled = value / 1_000_000
            suffix = "M"
        case 1_000...:
            scaled = value / 1_000
            suffix = "K"
        default:
            scaled = value
            suffix = ""
        }
        let digits = suffix.isEmpty ? 0 : 1
        let number = String(format: "%.\(digits)f", scaled)
        return "\(currency.symbol) \(number)\(suffix)"
    }
}
