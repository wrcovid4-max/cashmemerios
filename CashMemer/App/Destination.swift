import SwiftUI

/// The six top-level destinations: the iPad sidebar rows and the iPhone tab bar.
enum Destination: String, CaseIterable, Identifiable, Hashable {
    case newReceipt, history, dashboard, scan, rates, settings

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .newReceipt: return .newReceipt
        case .history: return .history
        case .dashboard: return .dashboard
        case .scan: return .scan
        case .rates: return .rates
        case .settings: return .settings
        }
    }

    /// Filled glyphs, matching the tab bar in the iPhone build.
    var systemImage: String {
        switch self {
        case .newReceipt: return "plus.circle.fill"
        case .history: return "list.bullet.rectangle.portrait.fill"
        case .dashboard: return "chart.bar.fill"
        case .scan: return "viewfinder"
        case .rates: return "dollarsign.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }

    /// The iPhone tab bar labels the New Receipt tab more explicitly than the sidebar.
    var tabKey: L10n.Key {
        self == .newReceipt ? .newReceipt : key
    }
}
