import Foundation

/// One tax on a memo, e.g. GST at 17%. Stored as JSON on the receipt.
struct MemoTaxLine: Equatable, Codable {
    var name: String
    var percent: Decimal

    static func encode(_ lines: [MemoTaxLine]) -> String {
        guard let data = try? JSONEncoder().encode(lines) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decode(_ json: String?) -> [MemoTaxLine] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MemoTaxLine].self, from: data)) ?? []
    }
}
