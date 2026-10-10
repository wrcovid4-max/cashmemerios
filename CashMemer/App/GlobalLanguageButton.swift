import SwiftUI

/// The global language selector: a globe that opens a menu listing every language.
struct GlobalLanguageButton: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var pending: AppLanguage?

    private var language: AppLanguage { settings.language }

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    if option != settings.language { pending = option }
                } label: {
                    if option == settings.language {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .frame(width: 36, height: 36)
                .background(Theme.card, in: Circle())
                .overlay(Circle().stroke(Theme.separator.opacity(0.5), lineWidth: 1))
        }
        .accessibilityLabel(L10n.string(.platformLanguages, language: language))
        .alert(
            L10n.string(.switchLanguageTitle, language: language),
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
        ) {
            Button(L10n.string(.switchLanguageConfirm, language: language)) {
                if let target = pending { settings.language = target }
                pending = nil
            }
            Button(L10n.string(.switchLanguageCancel, language: language), role: .cancel) {
                pending = nil
            }
        } message: {
            Text(L10n.string(.switchLanguageBody, language: language))
        }
    }
}
