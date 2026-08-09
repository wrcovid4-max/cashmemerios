import Foundation

/// Single lookup point for the third-party keys stored in `Info.plist`.
///
/// Reading them from the bundle rather than hard-coding them in Swift means a key
/// can be rotated by editing one plist entry, and the build can override them per
/// configuration without touching source.
enum APIKeys {
    static var gemini: String? { value(for: "GEMINI_API_KEY") }
    static var exchangeRate: String? { value(for: "EXCHANGE_RATE_API_KEY") }
    static var googleMaps: String? { value(for: "GOOGLE_MAPS_API_KEY") }

    /// `CLIENT_ID` from `GoogleService-Info.plist`, added to the target separately.
    static var googleClientID: String? {
        googleService?["CLIENT_ID"] as? String
    }

    static var googleReversedClientID: String? {
        googleService?["REVERSED_CLIENT_ID"] as? String
    }

    static var isGoogleSignInConfigured: Bool { googleClientID != nil }

    private static func value(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let googleService: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return nil }
        return plist as? [String: Any]
    }()
}
