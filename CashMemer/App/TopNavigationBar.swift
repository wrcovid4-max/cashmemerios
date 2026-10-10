import SwiftUI

/// The iPad's rounded tab bar across the top. The button at the end returns to the sidebar.
struct TopNavigationBar: View {
    @Binding var selection: Destination
    let onSidebar: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(Destination.phoneTabs) { destination in
                        Button {
                            selection = destination
                        } label: {
                            Label(
                                L10n.string(destination.tabKey, language: settings.language),
                                systemImage: destination.systemImage
                            )
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(selection == destination ? Color.white : Theme.textPrimary)
                            .background(selection == destination ? Theme.brand : Color.clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
            }
            Button(action: onSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.separator.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
    }
}
