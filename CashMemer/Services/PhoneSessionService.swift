import Combine
import CoreData
import Foundation
import WatchConnectivity

/// iPhone side of the watch link: publishes a trimmed receipt list whenever the
/// store changes, using `updateApplicationContext` so the watch always sees the
/// latest snapshot even if it was asleep for the earlier ones.
final class PhoneSessionService: NSObject, ObservableObject {
    static let shared = PhoneSessionService()

    private var lastPayload: WatchPayload?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(context: NSManagedObjectContext, settings: AppSettings) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        let request = CDReceipt.activeRequest()
        request.fetchLimit = 60
        guard let receipts = try? context.fetch(request) else { return }

        let payload = WatchPayload(
            generatedAt: Date(),
            currencySymbol: settings.defaultCurrency.symbol,
            receipts: receipts.map {
                WatchPayload.Summary(
                    id: $0.id,
                    number: $0.number,
                    store: $0.storeName.isEmpty ? $0.title : $0.storeName,
                    total: NSDecimalNumber(decimal: $0.totals.grandTotal).doubleValue,
                    date: $0.createdAt,
                    categoryRaw: $0.categoryRaw,
                    paymentRaw: $0.paymentMethodRaw
                )
            }
        )

        // Skip identical pushes; the radio cost is not worth a no-op update.
        guard payload.receipts != lastPayload?.receipts else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }

        try? WCSession.default.updateApplicationContext(["payload": data])
        lastPayload = payload
    }
}

extension PhoneSessionService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a switched watch keeps receiving updates.
        WCSession.default.activate()
    }
}
