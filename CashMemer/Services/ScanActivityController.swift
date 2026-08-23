import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Drives the scanner Live Activity through its phases.
///
/// OCR round-trips can take several seconds on a slow connection, and users put the
/// phone down while it works — the Live Activity keeps the result on the Lock Screen
/// and in the Dynamic Island instead of making them reopen the app to find out.
@MainActor
final class ScanActivityController {
    static let shared = ScanActivityController()

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activity: Activity<ScanActivityAttributes>? {
        get { _activity as? Activity<ScanActivityAttributes> }
        set { _activity = newValue }
    }
    private var _activity: Any?
    #endif

    private init() {}

    var isSupported: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    func start(source: String, currencySymbol: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), isSupported, activity == nil else { return }

        let attributes = ScanActivityAttributes(source: source, startedAt: Date())
        let state = ScanActivityAttributes.ContentState(
            phase: .capturing,
            progress: 0.1,
            itemsFound: 0,
            storeName: nil,
            total: nil,
            currencySymbol: currencySymbol
        )

        do {
            activity = try Activity.request(attributes: attributes, contentState: state)
        } catch {
            // A denied or rate-limited activity must never break the scan itself.
            activity = nil
        }
        #endif
    }

    func update(phase: ScanPhase, itemsFound: Int = 0, storeName: String? = nil, total: Decimal? = nil) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity = activity else { return }

        let state = ScanActivityAttributes.ContentState(
            phase: phase.attributePhase,
            progress: phase.progress,
            itemsFound: itemsFound,
            storeName: storeName,
            total: total.map { NSDecimalNumber(decimal: $0).doubleValue },
            currencySymbol: activity.contentState.currencySymbol
        )

        Task { await activity.update(using: state) }
        #endif
    }

    /// Leaves a finished activity on screen briefly so the result is readable.
    func finish(storeName: String?, itemsFound: Int, total: Decimal?, failed: Bool = false) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity = activity else { return }

        let state = ScanActivityAttributes.ContentState(
            phase: failed ? .failed : .finished,
            progress: 1,
            itemsFound: itemsFound,
            storeName: storeName,
            total: total.map { NSDecimalNumber(decimal: $0).doubleValue },
            currencySymbol: activity.contentState.currencySymbol
        )

        Task {
            await activity.end(using: state, dismissalPolicy: .after(.now + 8))
        }
        self.activity = nil
        #endif
    }

    func cancel() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity = activity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        self.activity = nil
        #endif
    }

    /// Phase vocabulary the app uses, decoupled from the ActivityKit availability gate.
    enum ScanPhase {
        case capturing, uploading, parsing

        var progress: Double {
            switch self {
            case .capturing: return 0.15
            case .uploading: return 0.45
            case .parsing: return 0.8
            }
        }

        @available(iOS 16.1, *)
        var attributePhase: ScanActivityAttributes.Phase {
            switch self {
            case .capturing: return .capturing
            case .uploading: return .uploading
            case .parsing: return .parsing
            }
        }
    }
}
