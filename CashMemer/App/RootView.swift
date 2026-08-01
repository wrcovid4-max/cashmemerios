import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLockService
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            // Regular width is the iPad experience: persistent sidebar with the
            // quick-overview panel docked beneath the destinations.
            if sizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .background(Theme.background)
        .overlay {
            if lock.isLocked && settings.appLockEnabled {
                LockScreenView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
        .onAppear {
            if settings.appLockEnabled { lock.lock() }
            navigation.consumePendingDestination()
        }
        .onChange(of: navigation.pendingDestination) { _ in
            navigation.consumePendingDestination()
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $navigation.selected)
                .navigationSplitViewColumnWidth(min: 300, ideal: 330, max: 380)
        } detail: {
            NavigationStack {
                content(for: navigation.selected)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var tabLayout: some View {
        TabView(selection: $navigation.selected) {
            ForEach(Destination.allCases) { destination in
                NavigationStack {
                    content(for: destination)
                }
                .tabItem {
                    Label(
                        L10n.string(destination.tabKey, language: settings.language),
                        systemImage: destination.systemImage
                    )
                }
                .tag(destination)
            }
        }
    }

    @ViewBuilder
    private func content(for destination: Destination) -> some View {
        switch destination {
        case .newReceipt: NewReceiptView()
        case .history: HistoryView()
        case .dashboard: DashboardView()
        case .scan: ScanView()
        case .rates: RatesView()
        case .settings: SettingsView()
        }
    }
}
