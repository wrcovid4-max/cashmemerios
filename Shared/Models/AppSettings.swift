import Foundation
import Observation

/// App-wide preferences, backed by `UserDefaults` and observed by the UI.
///
/// The language and theme live here rather than in SwiftData because the watch
/// app and the lock screen need them before the model container is ready.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var language: AppLanguage { didSet { store(language.rawValue, .language) } }
    var theme: AppTheme { didSet { store(theme.rawValue, .theme) } }
    var defaultCurrencyCode: String { didSet { store(defaultCurrencyCode, .currency) } }
    var appLockEnabled: Bool { didSet { store(appLockEnabled, .appLock) } }
    var biometricsEnabled: Bool { didSet { store(biometricsEnabled, .biometrics) } }
    var defaultSignaturePNG: Data? { didSet { store(defaultSignaturePNG, .signature) } }
    var googleAccountEmail: String? { didSet { store(googleAccountEmail, .googleEmail) } }
    var googleAccountName: String? { didSet { store(googleAccountName, .googleName) } }
    var customCurrencies: [Currency] { didSet { storeJSON(customCurrencies, .customCurrencies) } }
    var lastScanDate: Date? { didSet { store(lastScanDate, .lastScanDate) } }
    var scansToday: Int { didSet { store(scansToday, .scansToday) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawLanguage = defaults.string(forKey: Keys.language.rawValue)
        self.language = rawLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .english
        self.theme = defaults.string(forKey: Keys.theme.rawValue).flatMap(AppTheme.init(rawValue:)) ?? .system
        self.defaultCurrencyCode = defaults.string(forKey: Keys.currency.rawValue) ?? Currency.pkr.code
        self.appLockEnabled = defaults.bool(forKey: Keys.appLock.rawValue)
        self.biometricsEnabled = defaults.bool(forKey: Keys.biometrics.rawValue)
        self.defaultSignaturePNG = defaults.data(forKey: Keys.signature.rawValue)
        self.googleAccountEmail = defaults.string(forKey: Keys.googleEmail.rawValue)
        self.googleAccountName = defaults.string(forKey: Keys.googleName.rawValue)
        self.customCurrencies = Self.loadJSON([Currency].self, key: .customCurrencies, defaults: defaults) ?? []
        self.lastScanDate = defaults.object(forKey: Keys.lastScanDate.rawValue) as? Date
        self.scansToday = defaults.integer(forKey: Keys.scansToday.rawValue)

        // A counter labelled "Scans Today" must not carry over from yesterday.
        if let last = lastScanDate, !Calendar.current.isDateInToday(last) {
            scansToday = 0
        }
    }

    var isSignedIntoGoogle: Bool { googleAccountEmail != nil }

    /// Built-in currencies plus anything the user added in Settings.
    var availableCurrencies: [Currency] {
        var seen = Set<String>()
        return (Currency.builtIn + customCurrencies).filter { seen.insert($0.code).inserted }
    }

    var defaultCurrency: Currency {
        availableCurrencies.first { $0.code == defaultCurrencyCode } ?? .pkr
    }

    func recordScan(now: Date = .now) {
        if let last = lastScanDate, Calendar.current.isDateInToday(last) {
            scansToday += 1
        } else {
            scansToday = 1
        }
        lastScanDate = now
    }

    func text(_ key: L10n.Key) -> String {
        L10n.string(key, language: language)
    }

    // MARK: - Storage

    private enum Keys: String {
        case language = "settings.language"
        case theme = "settings.theme"
        case currency = "settings.defaultCurrency"
        case appLock = "settings.appLock"
        case biometrics = "settings.biometrics"
        case signature = "settings.defaultSignature"
        case googleEmail = "settings.googleEmail"
        case googleName = "settings.googleName"
        case customCurrencies = "settings.customCurrencies"
        case lastScanDate = "settings.lastScanDate"
        case scansToday = "settings.scansToday"
    }

    private func store(_ value: Any?, _ key: Keys) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func storeJSON<T: Encodable>(_ value: T, _ key: Keys) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key.rawValue)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, key: Keys, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
