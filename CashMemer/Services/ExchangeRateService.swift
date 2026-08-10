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

        /// Not an ISO code, so the API never quotes it and Foundation does not
        /// name it — but it is the unit Iran actually prices in.
        static let tomanCode = "TMN"

        /// The published rates plus the toman, synthesised at 1 TMN = 10 IRR.
        ///
        /// Derived in one place so the phone's Rates screen and the payload sent
        /// to the watch cannot drift apart.
        var ratesIncludingToman: [String: Decimal] {
            guard let rial = rates["IRR"] else { return rates }
            var all = rates
            all[Self.tomanCode] = rial / 10
            return all
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
        // The keyed v6 endpoint has the higher quota; the keyless one is the
        // fallback so the app still works if the key is missing or exhausted.
        var endpoints: [URL] = []
        if let key = APIKeys.exchangeRate,
           let keyed = URL(string: "https://v6.exchangerate-api.com/v6/\(key)/latest/\(base)") {
            endpoints.append(keyed)
        }
        if let open = URL(string: "https://open.er-api.com/v6/latest/\(base)") {
            endpoints.append(open)
        }

        var lastError: Error = RateError.badResponse
        for url in endpoints {
            do {
                let snapshot = try await fetch(url, base: base)
                cached = snapshot
                writeCache(snapshot)
                return snapshot
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func fetch(_ url: URL, base: String) async throws -> Snapshot {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RateError.badResponse
        }

        let payload = try JSONDecoder().decode(APIResponse.self, from: data)
        guard payload.result == "success" else { throw RateError.badResponse }

        // The keyed endpoint returns `conversion_rates`; the keyless one `rates`.
        guard let rates = payload.conversion_rates ?? payload.rates, !rates.isEmpty else {
            throw RateError.badResponse
        }

        return Snapshot(
            base: payload.base_code ?? base,
            rates: rates.mapValues { Decimal($0) },
            updatedAt: Date()
        )
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
        let base_code: String?
        let rates: [String: Double]?
        let conversion_rates: [String: Double]?
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
