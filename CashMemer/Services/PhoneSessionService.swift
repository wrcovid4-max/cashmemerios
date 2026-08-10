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

    func push(
        context: NSManagedObjectContext,
        settings: AppSettings,
        rates: ExchangeRateService.Snapshot? = nil
    ) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        let request = CDReceipt.activeRequest()
        request.fetchLimit = 60
        guard let receipts = try? context.fetch(request) else { return }

        let quotes = (rates?.ratesIncludingToman ?? [:])
            .map { WatchPayload.Rate(code: $0.key, value: NSDecimalNumber(decimal: $0.value).doubleValue) }
            .sorted { $0.code < $1.code }

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
            },
            baseCode: rates?.base ?? settings.defaultCurrencyCode,
            rates: quotes
        )

        // Skip identical pushes; the radio cost is not worth a no-op update.
        // Rates move without the receipts changing, so both have to be compared
        // — checking receipts alone would pin the watch to its first quote set.
        let unchanged = payload.receipts == lastPayload?.receipts
            && payload.rates == lastPayload?.rates
        guard !unchanged else { return }
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
