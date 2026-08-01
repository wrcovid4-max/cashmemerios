import SwiftUI

@main
struct CashMemerWatchApp: App {
    @StateObject private var session = WatchSessionService.shared
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
                .environmentObject(settings)
                .appLanguage(settings.language)
                .tint(Theme.brand)
        }
    }
}

/// Two pages, swipeable via the page dots: History and Dashboard. Nothing else —
/// creating a memo needs a keyboard and a signature, which belong on the phone.
struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchHistoryView()
            WatchDashboardView()
        }
        .tabViewStyle(.page)
    }
}
