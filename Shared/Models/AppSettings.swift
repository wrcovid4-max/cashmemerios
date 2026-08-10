import Combine
import Foundation

/// App-wide preferences, backed by the App Group `UserDefaults` so the widget
/// extension and Live Activity read the same language and currency as the app.
///
/// `ObservableObject` rather than `@Observable` — Xcode 14.2 predates Observation.
final class AppSettings: ObservableObject {
    /// Shared container so the app, widget extension and watch read one set of
    /// preferences. Declared here rather than on the Core Data stack because the
    /// watch target does not link Core Data.
    static let appGroupID = "group.com.cashmemer.shared"

    private let defaults: UserDefaults

    @Published var language: AppLanguage { didSet { store(language.rawValue, .language) } }
    @Published var theme: AppTheme { didSet { store(theme.rawValue, .theme) } }
    @Published var defaultCurrencyCode: String { didSet { store(defaultCurrencyCode, .currency) } }
    @Published var appLockEnabled: Bool { didSet { store(appLockEnabled, .appLock) } }
    @Published var biometricsEnabled: Bool { didSet { store(biometricsEnabled, .biometrics) } }
    @Published var defaultSignaturePNG: Data? { didSet { store(defaultSignaturePNG, .signature) } }
    @Published var googleAccountEmail: String? { didSet { store(googleAccountEmail, .googleEmail) } }
    @Published var googleAccountName: String? { didSet { store(googleAccountName, .googleName) } }
    @Published var customCurrencies: [Currency] { didSet { storeJSON(customCurrencies, .customCurrencies) } }
    @Published var lastScanDate: Date? { didSet { store(lastScanDate, .lastScanDate) } }
    @Published var scansToday: Int { didSet { store(scansToday, .scansToday) } }

    init(defaults: UserDefaults? = nil) {
        let store = defaults
            ?? UserDefaults(suiteName: AppSettings.appGroupID)
            ?? .standard
        self.defaults = store

        language = AppLanguage(rawValue: store.string(forKey: Keys.language.rawValue) ?? "") ?? .english
        theme = AppTheme(rawValue: store.string(forKey: Keys.theme.rawValue) ?? "") ?? .system
        defaultCurrencyCode = store.string(forKey: Keys.currency.rawValue) ?? Currency.usd.code
        appLockEnabled = store.bool(forKey: Keys.appLock.rawValue)
        biometricsEnabled = store.bool(forKey: Keys.biometrics.rawValue)
        defaultSignaturePNG = store.data(forKey: Keys.signature.rawValue)
        googleAccountEmail = store.string(forKey: Keys.googleEmail.rawValue)
        googleAccountName = store.string(forKey: Keys.googleName.rawValue)
        customCurrencies = Self.loadJSON([Currency].self, key: .customCurrencies, defaults: store) ?? []
        lastScanDate = store.object(forKey: Keys.lastScanDate.rawValue) as? Date
        scansToday = store.integer(forKey: Keys.scansToday.rawValue)

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
        availableCurrencies.first { $0.code == defaultCurrencyCode } ?? .usd
    }

    func recordScan(now: Date = Date()) {
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
