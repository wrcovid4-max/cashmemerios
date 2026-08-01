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
    func address(for location: CLLocation) async -> String? {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.country
        ]
        let address = components.compactMap { $0 }.joined(separator: ", ")
        return address.isEmpty ? nil : address
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
