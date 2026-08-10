import Foundation

/// Preferences, mirrored onto the Firestore user document.
///
/// These lived only in `UserDefaults`, which is device-local by design — so a
/// wiped Mac took the language, theme, currency, custom currencies and the saved
/// default signature with it. Everything else in this app survives in Firestore;
/// there was no reason these should not.
///
/// They are written onto `users/{uid}` itself rather than a subcollection,
/// **merged**, because the Android app keeps its own fields there — the account
/// name, photo and in-progress draft. Overwriting the document would delete them.
/// `defaultSignatureBase64` is deliberately the same key Android already uses, so
/// a signature drawn on either device shows up on the other.
enum SettingsDocument {
    /// The passcode is not here on purpose: it lives in the Keychain, and a
    /// passcode that syncs to the cloud is not really a passcode. The scan
    /// counters are per-device by nature.
    static func dictionary(from settings: AppSettings, stamp: Date) -> [String: Any] {
        var document: [String: Any] = [
            "settingsUpdatedAt": Int(stamp.timeIntervalSince1970 * 1000),
            "language": settings.language.rawValue,
            "theme": settings.theme.rawValue,
            "defaultCurrency": settings.defaultCurrencyCode,
            "appLockEnabled": settings.appLockEnabled,
            "biometricsEnabled": settings.biometricsEnabled
        ]

        if let signature = settings.defaultSignaturePNG,
           signature.count <= ReceiptDocument.maxSignatureBytes {
            document["defaultSignatureBase64"] = signature.base64EncodedString()
        }

        if !settings.customCurrencies.isEmpty {
            document["customCurrencies"] = settings.customCurrencies.map {
                ["code": $0.code, "symbol": $0.symbol, "name": $0.name]
            }
        }

        return document
    }

    /// Applies remote preferences. The caller decides whether they are newer.
    static func apply(_ document: [String: Any], to settings: AppSettings) {
        if let raw = document["language"] as? String, let value = AppLanguage(rawValue: raw) {
            settings.language = value
        }
        if let raw = document["theme"] as? String, let value = AppTheme(rawValue: raw) {
            settings.theme = value
        }
        if let code = document["defaultCurrency"] as? String, !code.isEmpty {
            settings.defaultCurrencyCode = code
        }
        if let value = document["appLockEnabled"] as? Bool {
            settings.appLockEnabled = value
        }
        if let value = document["biometricsEnabled"] as? Bool {
            settings.biometricsEnabled = value
        }
        if let encoded = document["defaultSignatureBase64"] as? String,
           let data = Data(base64Encoded: encoded) {
            settings.defaultSignaturePNG = data
        }
        if let rows = document["customCurrencies"] as? [[String: Any]] {
            let decoded = rows.compactMap { row -> Currency? in
                guard
                    let code = row["code"] as? String,
                    let symbol = row["symbol"] as? String
                else { return nil }
                return Currency(code: code, symbol: symbol, name: row["name"] as? String ?? code)
            }
            if !decoded.isEmpty { settings.customCurrencies = decoded }
        }
    }

    static func stamp(_ document: [String: Any]) -> Date? {
        AndroidReceiptDocument.date(document["settingsUpdatedAt"])
    }
}
