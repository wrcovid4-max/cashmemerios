import SwiftUI

/// A small (i) button that opens a plain-language explanation. The iOS counterpart
/// of the Android (i) popups; the title is shown in bold by the system alert.
struct InfoButton: View {
    let title: String
    let message: String

    @Environment(\.appLanguage) private var language
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            if Holiday.halloween {
                Text("👻")
                    .font(.body)
            } else {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundColor(Theme.brand)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(title))
        .alert(title, isPresented: $isShowing) {
            Button(L10n.string(.gotIt, language: language), role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
