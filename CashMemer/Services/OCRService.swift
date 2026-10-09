import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// Everything the scanner can pull off a paper receipt, ready to populate the form.
struct ScannedReceipt: Equatable {
    var storeName: String?
    var address: String?
    var date: Date?
    var category: ReceiptCategory?
    var paymentMethod: PaymentMethod?
    var currencyCode: String?
    var lines: [Line]
    var taxPercent: Decimal?
    var total: Decimal?
    var extraFees: Decimal?
    var taxes: [ScannedTax] = []

    struct ScannedTax: Equatable {
        var name: String
        var percent: Decimal
    }

    struct Line: Equatable {
        var name: String
        var quantity: Int
        var unitPrice: Decimal
    }

    static let empty = ScannedReceipt(lines: [])
}

protocol ReceiptScanning {
    func scan(imageData: Data) async throws -> ScannedReceipt
}

// MARK: - Gemini

/// Parses a receipt photo with Gemini, which handles the messy real-world layouts
/// (skewed thermal paper, Urdu/English mixed text) that plain OCR gets wrong.
struct GeminiReceiptScanner: ReceiptScanning {
    static var apiKey: String? { APIKeys.gemini }

    /// Newest model first; falls back to the next one if the newest stays busy.
    /// Matches the Android scanner (GeminiOcrClient.MODELS).
    var models = ["gemini-3.8-flash", "gemini-3.6-flash"]
    var session: URLSession = .shared

    /// Busy or overloaded responses worth retrying (matches Android RETRYABLE).
    private static let retryable: Set<Int> = [429, 500, 503]

    func scan(imageData: Data) async throws -> ScannedReceipt {
        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            throw ScanError.missingAPIKey
        }
        let body = try JSONSerialization.data(withJSONObject: requestBody(imageData: imageData))

        var lastError: Error = ScanError.badResponse
        for model in models {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
                continue
            }
            for attempt in 1...3 {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                request.httpBody = body

                let (data, response) = try await session.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if (200...299).contains(code) {
                    return try parse(data)
                }
                lastError = ScanError.http(code, String(data: data, encoding: .utf8) ?? "")
                // Not a busy error (for example, model unavailable): try the next model.
                if !Self.retryable.contains(code) { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
        }
        throw lastError
    }

    private func parse(_ data: Data) throws -> ScannedReceipt {
        let envelope = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = envelope.candidates.first?.content.parts.first?.text,
              let payload = text.data(using: .utf8) else {
            throw ScanError.unreadable
        }
        return try JSONDecoder().decode(ParsedReceipt.self, from: payload).asScannedReceipt
    }

    private func requestBody(imageData: Data) -> [String: Any] {
        [
            "contents": [[
                "parts": [
                    ["text": Self.prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                // Structured output keeps the reply parseable without regex cleanup.
                "response_mime_type": "application/json",
                "response_schema": Self.responseSchema,
                "temperature": 0
            ]
        ]
    }

    private static let prompt = """
    Extract the contents of this shop receipt. Amounts must be plain numbers with no \
    currency symbols or thousands separators. Use ISO 4217 for currency (USD when the \
    receipt shows $, PKR when it shows Rs). Use ISO 8601 for the date. Omit any field \
    the receipt does not show rather than guessing. Category must be one of: \
    shopping, groceries, food, fuel, \
    travel, utilities, health, education, services, other.
    Pakistani receipts often show several taxes, so look for every one and its percentage: \
    GST, G.S.T, General Sales Tax, Sales Tax, S.Tax, Sindh Sales Tax, SST, Punjab Sales Tax, \
    KPK Sales Tax, Balochistan Sales Tax, Further Tax, Further GST, Further Sales Tax, FED, \
    Federal Excise Duty, Excise Duty, WHT, Withholding Tax, Income Tax, Advance Income Tax, \
    Advance Tax, Service Charge, Service Tax, Stamp Duty, Octroi, Extra Tax, PRA Tax. \
    Set taxPercent to the combined percentage of all of them. If a tax shows only an amount, \
    work out its percentage from the subtotal.
    List each tax in taxes with its name and percent. Put delivery, packing or service fees that are not tax in extraFees as an amount.
    """

    private static let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "storeName": ["type": "STRING"],
            "address": ["type": "STRING"],
            "date": ["type": "STRING"],
            "category": ["type": "STRING"],
            "paymentMethod": ["type": "STRING"],
            "currencyCode": ["type": "STRING"],
            "taxPercent": ["type": "NUMBER"],
            "total": ["type": "NUMBER"],
            "extraFees": ["type": "NUMBER"],
            "taxes": ["type": "ARRAY", "items": ["type": "OBJECT", "properties": ["name": ["type": "STRING"], "percent": ["type": "NUMBER"]], "required": ["name", "percent"]]],
            "lines": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "name": ["type": "STRING"],
                        "quantity": ["type": "INTEGER"],
                        "unitPrice": ["type": "NUMBER"]
                    ],
                    "required": ["name", "quantity", "unitPrice"]
                ]
            ]
        ],
        "required": ["lines"]
    ]

    // MARK: Wire types

    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
    }

    private struct ParsedReceipt: Decodable {
        struct Tax: Decodable {
            let name: String
            let percent: Double?
        }
        struct Line: Decodable {
            let name: String
            let quantity: Int?
            let unitPrice: Double?
        }
        let storeName: String?
        let address: String?
        let date: String?
        let category: String?
        let paymentMethod: String?
        let currencyCode: String?
        let taxPercent: Double?
        let total: Double?
        let extraFees: Double?
        let taxes: [Tax]?
        let lines: [Line]

        var asScannedReceipt: ScannedReceipt {
            ScannedReceipt(
                storeName: storeName,
                address: address,
                date: date.flatMap { ISO8601DateFormatter().date(from: $0) },
                category: category.flatMap { ReceiptCategory(rawValue: $0.lowercased()) },
                paymentMethod: paymentMethod.flatMap { PaymentMethod(rawValue: $0) },
                currencyCode: currencyCode,
                lines: lines.map {
                    ScannedReceipt.Line(
                        name: $0.name,
                        quantity: $0.quantity ?? 1,
                        unitPrice: Decimal($0.unitPrice ?? 0)
                    )
                },
                taxPercent: taxPercent.map { Decimal($0) },
                total: total.map { Decimal($0) },
                extraFees: extraFees.map { Decimal($0) },
                taxes: (taxes ?? []).map { ScannedReceipt.ScannedTax(name: $0.name, percent: Decimal($0.percent ?? 0)) }
            )
        }
    }

    enum ScanError: LocalizedError {
        case missingAPIKey, badResponse, unreadable
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .http(let code, let body):
                return "Gemini request failed: HTTP \(code) \(body)"
            case .missingAPIKey:
                return "Add your Gemini API key as GEMINI_API_KEY in Info.plist to enable AI scanning."
            case .badResponse:
                return "The scanner could not reach Gemini. Check your connection and try again."
            case .unreadable:
                return "That receipt could not be read. Try a sharper, better-lit photo."
            }
        }
    }
}

// MARK: - On-device fallback

/// Vision text recognition. Used when no Gemini key is configured — it recovers the
/// store name and a total, which is enough to save the user most of the typing.
struct VisionReceiptScanner: ReceiptScanning {
    func scan(imageData: Data) async throws -> ScannedReceipt {
        #if canImport(UIKit)
        guard let cgImage = UIImage(data: imageData)?.cgImage else { return .empty }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }

        return ScannedReceipt(
            storeName: lines.first,
            lines: [],
            total: Self.largestAmount(in: lines)
        )
        #else
        return .empty
        #endif
    }

    /// The grand total is almost always the largest number printed on a receipt.
    private static func largestAmount(in lines: [String]) -> Decimal? {
        let pattern = /[0-9]+(?:[.,][0-9]{1,2})?/
        return lines
            .flatMap { $0.matches(of: pattern) }
            .compactMap { Decimal(string: $0.output.replacingOccurrences(of: ",", with: "")) }
            .max()
    }
}
