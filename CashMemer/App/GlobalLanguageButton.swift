import SwiftUI
import LanguageKit
import LanguageKitUI

/// The global language selector: the shared globe menu, wired to the app's settings.
struct GlobalLanguageButton: View {
    @EnvironmentObject private var settings: AppSettings

    private var language: AppLanguage { settings.language }

    var body: some View {
        LanguageGlobeMenu(
            selected: settings.language,
            texts: LanguageMenuTexts(
                accessibilityLabel: L10n.string(.platformLanguages, language: language),
                title: L10n.string(.switchLanguageTitle, language: language),
                body: L10n.string(.switchLanguageBody, language: language),
                confirm: L10n.string(.switchLanguageConfirm, language: language),
                cancel: L10n.string(.switchLanguageCancel, language: language)
            ),
            tint: Theme.brand,
            onSelect: { settings.language = $0 }
        )
    }
}
