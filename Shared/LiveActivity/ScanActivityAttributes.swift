import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shape of the scanner Live Activity, shared by the app (which drives it) and the
/// widget extension (which renders it).
@available(iOS 16.1, *)
struct ScanActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: Phase
        /// 0…1 for the progress ring. Indeterminate phases still report a best guess.
        var progress: Double
        var itemsFound: Int
        var storeName: String?
        var total: Double?
        var currencySymbol: String

        var headline: String {
            switch phase {
            case .capturing: return "Capturing receipt"
            case .uploading: return "Uploading to Gemini"
            case .parsing: return "Reading line items"
            case .finished: return storeName ?? "Receipt scanned"
            case .failed: return "Scan failed"
            }
        }

        var detail: String {
            switch phase {
            case .capturing: return "Hold steady"
            case .uploading: return "Sending image"
            case .parsing: return itemsFound > 0 ? "\(itemsFound) items so far" : "Analysing"
            case .finished:
                guard let total = total else {
                    return itemsFound == 1 ? "1 item" : "\(itemsFound) items"
                }
                return "\(currencySymbol) \(String(format: "%.2f", total)) · \(itemsFound) items"
            case .failed: return "Tap to try again"
            }
        }

        var isTerminal: Bool { phase == .finished || phase == .failed }
    }

    public enum Phase: String, Codable, Hashable {
        case capturing, uploading, parsing, finished, failed

        var symbolName: String {
            switch self {
            case .capturing: return "camera.viewfinder"
            case .uploading: return "arrow.up.circle"
            case .parsing: return "sparkles"
            case .finished: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }
    }

    /// Where the scan came from — shown as the activity's subtitle.
    var source: String
    var startedAt: Date
}
