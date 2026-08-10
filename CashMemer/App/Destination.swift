import SwiftUI

/// The seven top-level destinations: the iPad sidebar rows and the iPhone tab bar.
/// Members sits third, promoted out of Settings — it is a place you go, not a
/// preference you set.
enum Destination: String, CaseIterable, Identifiable, Hashable {
    case newReceipt, history, members, dashboard, scan, rates, settings, more

    var id: String { rawValue }

    var key: L10n.Key {
        switch self {
        case .newReceipt: return .newReceipt
        case .history: return .history
        case .members: return .membersDirectory
        case .dashboard: return .dashboard
        case .scan: return .scan
        case .rates: return .rates
        case .settings: return .settings
        case .more: return .more
        }
    }

    /// Filled glyphs, matching the tab bar in the iPhone build.
    var systemImage: String {
        switch self {
        case .newReceipt: return "plus.circle.fill"
        case .history: return "list.bullet.rectangle.portrait.fill"
        case .members: return "person.2.fill"
        case .dashboard: return "chart.bar.fill"
        case .scan: return "viewfinder"
        case .rates: return "dollarsign.circle.fill"
        case .settings: return "gearshape.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }

    /// The iPhone tab bar labels the New Receipt tab more explicitly than the sidebar.
    var tabKey: L10n.Key {
        self == .newReceipt ? .newReceipt : key
    }

    /// iPad sidebar rows. Every real screen — More is a phone-only affordance.
    static var sidebarDestinations: [Destination] {
        allCases.filter { $0 != .more }
    }

    /// iPhone tab bar. Five is the most iOS shows before inserting a More tab of
    /// its own, and that system tab is worth staying under: it wraps each screen
    /// in a second UINavigationController, which is what doubles the navigation
    /// bar and leaves a band of empty space above the title, and iOS localises
    /// its chrome from the system language, so "More" stayed English while the
    /// rest of the app switched to Urdu. This More tab is ours instead.
    static var phoneTabs: [Destination] {
        [.newReceipt, .history, .members, .dashboard, .more]
    }

    /// Reached one tap deeper, through More. Scan earns its place here rather
    /// than on the bar because New Receipt already opens the scanner directly.
    static var moreDestinations: [Destination] {
        [.scan, .rates, .settings]
    }
}
