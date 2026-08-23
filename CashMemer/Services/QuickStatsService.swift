import CoreLocation
import Combine
import Foundation

/// Feeds the sidebar's Quick Overview panel and the Rates screen: FX rates, the
/// weather tile and whether the rate API is reachable.
@MainActor
final class QuickStatsService: ObservableObject {
    @Published private(set) var rates: ExchangeRateService.Snapshot?
    @Published private(set) var weather: WeatherConditions?
    @Published private(set) var isRateAPIOnline = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    private let rateService = ExchangeRateService()
    private let locationService = LocationService()

    /// Currencies shown as chips in the sidebar. The base is filtered out where
    /// they are rendered, so this can list it without producing a "USD → USD" chip.
    static let chipCodes = ["EUR", "GBP", "PKR", "SAR"]

    func start(settings: AppSettings) async {
        rates = await rateService.lastSnapshot
        await refresh(base: settings.defaultCurrencyCode)
    }

    func refresh(base: String) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            rates = try await rateService.refresh(base: base)
            isRateAPIOnline = true
            lastError = nil
        } catch {
            isRateAPIOnline = false
            lastError = error.localizedDescription
        }

        await refreshWeather()
    }

    func refreshWeather() async {
        guard let location = await locationService.currentLocation() else { return }
        weather = await WeatherProvider.current(for: location)
    }

    /// `277.90` for USD — how many units of the base currency buy one USD.
    func inverseRate(for code: String) -> Decimal? {
        rates?.inverseRate(for: code)
    }

    var updatedAtText: String? {
        guard let updatedAt = rates?.updatedAt else { return nil }
        return updatedAt.formatted(date: .omitted, time: .shortened)
    }
}
