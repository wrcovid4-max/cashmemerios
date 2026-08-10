import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLockService
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// What the More tab currently has pushed. Driven by deep links as well as taps.
    @State private var morePath: [Destination] = []

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
        .splashScreen()
        .onAppear {
            if settings.appLockEnabled { lock.lock() }
            navigation.consumePendingDestination()
        }
        .onChange(of: navigation.pendingDestination) { _ in
            navigation.consumePendingDestination()
        }
        .onChange(of: navigation.selected) { destination in
            // Selecting a More-only screen has to push it as well as switch tabs.
            if Destination.moreDestinations.contains(destination) {
                morePath = [destination]
            }
        }
    }

    /// The phone's More screen — ours, not the system's, so its title and rows
    /// follow the in-app language toggle and it adds only one navigation bar.
    private struct MoreListView: View {
        @Environment(\.appLanguage) private var language

        var body: some View {
            List {
                ForEach(Destination.moreDestinations) { destination in
                    NavigationLink(value: destination) {
                        Label(
                            L10n.string(destination.key, language: language),
                            systemImage: destination.systemImage
                        )
                        .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(L10n.string(.more, language: language))
            .navigationBarTitleDisplayMode(.inline)
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
        TabView(selection: tabSelection) {
            ForEach(Destination.phoneTabs) { destination in
                tabContent(for: destination)
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
    private func tabContent(for destination: Destination) -> some View {
        if destination == .more {
            NavigationStack(path: $morePath) {
                MoreListView()
                    .navigationDestination(for: Destination.self) { content(for: $0) }
            }
        } else {
            NavigationStack {
                content(for: destination)
            }
        }
    }

    /// Anything that lives behind More has no tab of its own, so a selection like
    /// `.settings` — arriving from a deep link, an intent or a Spotlight result —
    /// would match no tab and leave the bar with nothing highlighted. Map those
    /// onto the More tab; `morePath` then pushes the screen itself.
    private var tabSelection: Binding<Destination> {
        Binding(
            get: {
                let selected = navigation.selected
                return Destination.phoneTabs.contains(selected) ? selected : .more
            },
            set: { navigation.selected = $0 }
        )
    }

    @ViewBuilder
    private func content(for destination: Destination) -> some View {
        switch destination {
        case .newReceipt: NewReceiptView()
        case .history: HistoryView()
        case .members: MembersDirectoryView()
        case .dashboard: DashboardView()
        case .scan: ScanView()
        case .rates: RatesView()
        case .settings: SettingsView()
        case .more: MoreListView()
        }
    }
}
