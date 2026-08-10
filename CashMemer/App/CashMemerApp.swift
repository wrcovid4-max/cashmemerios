import CoreData
import CoreSpotlight
import FirebaseCore
import SwiftUI
import WidgetKit

@main
struct CashMemerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var lock = AppLockService()
    @StateObject private var quickStats = QuickStatsService()
    @StateObject private var navigation = AppNavigation.shared
    @Environment(\.scenePhase) private var scenePhase

    private let persistence = PersistenceController.shared

    init() {
        // Must run before any Firebase API is touched.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(settings)
                .environmentObject(lock)
                .environmentObject(quickStats)
                .environmentObject(navigation)
                .appLanguage(settings.language)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(Theme.brand)
                .task {
                    // Restoring the session starts Firestore sync on success.
                    GoogleAuthService.shared.restorePreviousSignIn(into: settings)
                    await quickStats.start(settings: settings)
                }
                .onOpenURL { url in
                    // Google's callback comes back on its own scheme.
                    if GoogleAuthService.shared.handle(url: url) { return }
                    navigation.handle(url: url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { navigation.handle(userActivity: $0) }
                .onContinueUserActivity(SpotlightIndex.activityType) { navigation.handle(userActivity: $0) }
                // Any save — from the UI, an App Intent or a restore — refreshes
                // the watch payload and the widget timeline.
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .NSManagedObjectContextDidSave,
                        object: persistence.container.viewContext
                    )
                ) { _ in
                    PhoneSessionService.shared.push(
                        context: persistence.container.viewContext,
                        settings: settings
                    )
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onAppear {
                    PhoneSessionService.shared.push(
                        context: persistence.container.viewContext,
                        settings: settings
                    )
                }
        }
        .onChange(of: scenePhase) { phase in
            // Re-arm the lock as soon as the app leaves the foreground, so a
            // backgrounded app never comes back already unlocked.
            if phase != .active, settings.appLockEnabled {
                lock.lock()
            }
        }
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
