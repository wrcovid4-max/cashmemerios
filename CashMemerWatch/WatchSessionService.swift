import Combine
import Foundation
import WatchConnectivity

/// Watch side of the link. Caches the last payload to disk so History still has
/// content when the app launches out of range of the phone.
final class WatchSessionService: NSObject, ObservableObject {
    static let shared = WatchSessionService()

    @Published private(set) var payload: WatchPayload = .empty
    @Published private(set) var hasEverSynced = false

    private let cacheURL: URL = {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("watch-payload.json")
    }()

    private override init() {
        super.init()
        loadCache()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Asks the phone to send a fresh snapshot, used by pull-to-refresh.
    func requestRefresh() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["request": "payload"], replyHandler: { [weak self] reply in
            guard let data = reply["payload"] as? Data else { return }
            self?.apply(data)
        }, errorHandler: nil)
    }

    private func apply(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        DispatchQueue.main.async {
            self.payload = decoded
            self.hasEverSynced = true
        }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        payload = decoded
        hasEverSynced = true
    }
}

extension WatchSessionService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let data = session.receivedApplicationContext["payload"] as? Data {
            apply(data)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["payload"] as? Data else { return }
        apply(data)
    }
}
