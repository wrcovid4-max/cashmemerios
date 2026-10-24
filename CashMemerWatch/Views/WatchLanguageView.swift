import SwiftUI
import LanguageKit

/// Watch language picker. The choice applies at once and is saved on this watch only.
struct WatchLanguageView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showInfo = false

    var body: some View {
        List {
            Button {
                showInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(Theme.brand)
            }
            if showInfo {
                Text(L10n.string(.watchLanguageInfo, language: settings.language))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            ForEach(AppLanguage.allCases) { option in
                Button {
                    settings.language = option
                } label: {
                    HStack {
                        Text(option.displayName)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        if option == settings.language {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.string(.platformLanguages, language: settings.language))
    }
}
