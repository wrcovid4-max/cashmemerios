import SwiftUI
import LanguageKit

/// Watch language picker. The choice applies at once and is saved on this watch only.
struct WatchLanguageView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
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
