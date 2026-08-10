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

    var model = "gemini-2.0-flash"
    var session: URLSession = .shared

    func scan(imageData: Data) async throws -> ScannedReceipt {
        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            throw ScanError.missingAPIKey
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw ScanError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(imageData: imageData))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ScanError.badResponse
        }

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
                total: total.map { Decimal($0) }
            )
        }
    }

    enum ScanError: LocalizedError {
        case missingAPIKey, badResponse, unreadable

        var errorDescription: String? {
            switch self {
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
