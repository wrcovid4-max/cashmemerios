import Foundation

enum AskAIError: LocalizedError {
    case noKey
    case failed

    var errorDescription: String? {
        switch self {
        case .noKey: return "Add your Gemini API key to enable Ask AI."
        case .failed: return "Ask AI could not get an answer right now."
        }
    }
}

/// Chat-style calls to Gemini, with the same model fallback and retries as the scanner.
enum GeminiChat {
    private static let models = ["gemini-3.8-flash", "gemini-3.6-flash"]
    private static let retryable: Set<Int> = [429, 500, 503]

    static func generate(_ body: [String: Any]) async throws -> [String: Any] {
        guard let key = APIKeys.gemini, !key.isEmpty else { throw AskAIError.noKey }
        let payload = try JSONSerialization.data(withJSONObject: body)
        for model in models {
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else { continue }
            for attempt in 1...3 {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                request.httpBody = payload
                let (reply, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if (200...299).contains(code) {
                    guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any] else {
                        throw AskAIError.failed
                    }
                    return object
                }
                if !retryable.contains(code) { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
        }
        throw AskAIError.failed
    }
}
