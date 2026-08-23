import CoreLocation
import Foundation

/// One-shot location lookups for the receipt's GPS address field.
///
/// The app only ever needs a fix at the moment the user taps the locate button, so
/// this requests when-in-use authorisation and stops updating immediately after.
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocation?, Never>] = []
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Resolves with the device's location, or `nil` if permission was denied or the
    /// fix failed. Never throws — a missing address is a soft failure on a receipt.
    func currentLocation() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        default:
            break
        }

        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -120 {
            return recent
        }

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            manager.requestLocation()
        }
    }

    /// Reverse-geocodes into the one-line address printed under "Saved Location".
    ///
    /// Apple's geocoder is tried first — it needs no key and no network round-trip
    /// of our own — with Google Geocoding as the fallback, because `CLGeocoder`
    /// rate-limits hard and returns nothing when it does.
    func address(for location: CLLocation) async -> String? {
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            let components = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.subLocality,
                placemark.locality,
                placemark.country
            ]
            let address = components.compactMap { $0 }.joined(separator: ", ")
            if !address.isEmpty { return address }
        }
        return await googleAddress(for: location)
    }

    private func googleAddress(for location: CLLocation) async -> String? {
        guard let key = APIKeys.googleMaps else { return nil }

        let coordinate = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")
        components?.queryItems = [
            URLQueryItem(name: "latlng", value: coordinate),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let payload = try JSONDecoder().decode(GeocodeResponse.self, from: data)
            guard payload.status == "OK" else { return nil }
            return payload.results.first?.formatted_address
        } catch {
            return nil
        }
    }

    private struct GeocodeResponse: Decodable {
        struct Result: Decodable { let formatted_address: String }
        let status: String
        let results: [Result]
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }

    private func resume(with location: CLLocation?) {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(returning: location) }
    }
}
