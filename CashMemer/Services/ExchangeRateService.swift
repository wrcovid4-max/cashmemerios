import Foundation

/// Live FX rates for the Rates screen and the sidebar's currency chips.
///
/// Backed by open.er-api.com, which serves daily rates without an API key. Results
/// are cached to disk so the app still shows the last known rates when offline.
actor ExchangeRateService {
    struct Snapshot: Codable, Equatable {
        var base: String
        /// Units of the quoted currency per 1 unit of `base` (1 PKR = 0.0096 USD).
        var rates: [String: Decimal]
        var updatedAt: Date

        /// How many units of `base` buy one `code` — the "USD → PKR 277.90" chip.
        func inverseRate(for code: String) -> Decimal? {
            guard let rate = rates[code], rate > 0 else { return nil }
            return (1 / rate).rounded(2)
        }
    }

    private var cached: Snapshot?
    private let session: URLSession
    private let cacheURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        self.cacheURL = URL.cachesDirectory.appending(path: "exchange-rates.json")
        self.cached = Self.readCache(at: cacheURL)
    }

    var lastSnapshot: Snapshot? { cached }

    /// Returns cached rates when they are still from today, otherwise refetches.
    func rates(base: String) async throws -> Snapshot {
        if let cached, cached.base == base, Calendar.current.isDateInToday(cached.updatedAt) {
            return cached
        }
        return try await refresh(base: base)
    }

    @discardableResult
    func refresh(base: String) async throws -> Snapshot {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(base)") else {
            throw RateError.badResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RateError.badResponse
        }

        let payload = try JSONDecoder().decode(APIResponse.self, from: data)
        guard payload.result == "success" else { throw RateError.badResponse }

        let snapshot = Snapshot(
            base: payload.base_code,
            rates: payload.rates.mapValues { Decimal($0) },
            updatedAt: Date()
        )
        cached = snapshot
        writeCache(snapshot)
        return snapshot
    }

    // MARK: - Cache

    private func writeCache(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func readCache(at url: URL) -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private struct APIResponse: Decodable {
        let result: String
        let base_code: String
        let rates: [String: Double]
    }

    enum RateError: LocalizedError {
        case badResponse

        var errorDescription: String? {
            switch self {
            case .badResponse: return "Exchange rates are unavailable right now."
            }
        }
    }
}
