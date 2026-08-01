import SwiftUI

/// The iPad sidebar: brand, destinations, the Quick Overview panel and a contact footer.
struct SidebarView: View {
    @Binding var selection: Destination

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.string(.appName, language: settings.language))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.m)

            destinationList

            Divider().padding(.vertical, Theme.Spacing.m)

            ScrollView {
                QuickOverviewPanel()
                    .padding(.horizontal, Theme.Spacing.l)
            }

            Divider()

            ContactFooter()
                .padding(Theme.Spacing.l)
        }
        .padding(.top, Theme.Spacing.s)
        .background(Theme.background)
    }

    private var destinationList: some View {
        VStack(spacing: 2) {
            ForEach(Destination.allCases) { destination in
                SidebarRow(
                    destination: destination,
                    isSelected: selection == destination,
                    language: settings.language
                ) {
                    selection = destination
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
    }
}

private struct SidebarRow: View {
    let destination: Destination
    let isSelected: Bool
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 18))
                    .frame(width: 26)
                    .foregroundStyle(isSelected ? .white : Theme.brand)
                Text(L10n.string(destination.key, language: language))
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(isSelected ? Theme.brand : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// "Contact Us!" block pinned to the bottom of the sidebar.
struct ContactFooter: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(.contactUs, language: settings.language))
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            row(label: .mail, value: AppInfo.supportEmail, url: URL(string: "mailto:\(AppInfo.supportEmail)"))
            row(label: .web, value: AppInfo.website, url: URL(string: "https://\(AppInfo.website)"))
            row(label: .social, value: AppInfo.socialHandle, url: AppInfo.socialURL)

            Text(L10n.string(.contactResponseNote, language: settings.language))
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func row(label: L10n.Key, value: String, url: URL?) -> some View {
        HStack(spacing: 4) {
            Text(L10n.string(label, language: settings.language) + ":")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            if let url {
                Link(value, destination: url)
                    .font(.caption2)
                    .foregroundStyle(Theme.brand)
            } else {
                Text(value)
                    .font(.caption2)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}

enum AppInfo {
    static let supportEmail = "support@cashmemer.com"
    static let website = "www.cashmemer.com"
    static let socialHandle = "@cashmemerapp"
    static let socialURL = URL(string: "https://twitter.com/cashmemerapp")

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
