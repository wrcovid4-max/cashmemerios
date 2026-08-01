import Combine
import CoreSpotlight
import Foundation

/// Single routing surface for everything that can drive the app from outside:
/// App Intents, Siri, Spotlight results, widgets and `cashmemer://` URLs.
@MainActor
final class AppNavigation: ObservableObject {
    static let shared = AppNavigation()

    @Published var selected: Destination = .newReceipt
    /// Set by an intent before the app comes forward; consumed on the next render.
    @Published var pendingDestination: Destination?
    @Published var pendingReceiptID: UUID?

    private init() {}

    func consumePendingDestination() {
        guard let pending = pendingDestination else { return }
        selected = pending
        pendingDestination = nil
    }

    /// Handles `cashmemer://receipt/<uuid>` and `cashmemer://scan`.
    func handle(url: URL) {
        guard url.scheme == "cashmemer" else { return }
        switch url.host {
        case "receipt":
            let component = url.pathComponents.first { $0 != "/" }
            if let component = component, let id = UUID(uuidString: component) {
                pendingReceiptID = id
                selected = .history
            }
        case "scan":
            selected = .scan
        case "dashboard":
            selected = .dashboard
        case "new":
            selected = .newReceipt
        default:
            break
        }
    }

    /// Handles a Spotlight result tap, which arrives as an `NSUserActivity`.
    func handle(userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let id = UUID(uuidString: identifier) else { return }
        pendingReceiptID = id
        selected = .history
    }
}
