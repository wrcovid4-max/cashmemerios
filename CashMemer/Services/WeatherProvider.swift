import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Current conditions for the sidebar tile and the watch app header.
struct WeatherConditions: Equatable, Codable {
    var temperatureCelsius: Int
    var condition: String
    var humidityPercent: Int
    var windKilometresPerHour: Int
    var symbolName: String

    var temperatureText: String { "\(temperatureCelsius)°C" }
}

/// Wraps WeatherKit so callers do not have to care whether the entitlement is
/// provisioned — an unprovisioned build simply reports `nil` and the UI hides the tile.
enum WeatherProvider {
    static func current(for location: CLLocation) async -> WeatherConditions? {
        #if canImport(WeatherKit)
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            return WeatherConditions(
                temperatureCelsius: Int(current.temperature.converted(to: .celsius).value.rounded()),
                condition: current.condition.description,
                humidityPercent: Int((current.humidity * 100).rounded()),
                windKilometresPerHour: Int(current.wind.speed.converted(to: .kilometersPerHour).value.rounded()),
                symbolName: current.symbolName
            )
        } catch {
            // WeatherKit throws when the entitlement is missing or the network is down;
            // neither is worth surfacing on a receipts app, so degrade quietly.
            return nil
        }
        #else
        return nil
        #endif
    }
}
