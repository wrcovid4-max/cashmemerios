import Foundation

/// Stores how a bill is split between two customers. An empty string means not split.
enum BillSplit {
    static func encode(enabled: Bool, first: Decimal?) -> String {
        guard enabled else { return "" }
        let value: Any
        if let first {
            value = NSDecimalNumber(decimal: first).doubleValue
        } else {
            value = NSNull()
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ["first": value]) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func isSplit(_ json: String?) -> Bool {
        !(json ?? "").isEmpty
    }

    /// What Customer 1 pays, or nil when the bill is split equally.
    static func first(_ json: String?) -> Decimal? {
        guard let json, let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["first"] as? Double else { return nil }
        return Decimal(value)
    }
}
