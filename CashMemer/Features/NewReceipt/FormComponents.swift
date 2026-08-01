import SwiftUI
import UIKit

/// An uppercase caption above a white rounded card — the grouping used throughout
/// the New Receipt form and Settings.
struct FormSection<Content: View>: View {
    let titleKey: L10n.Key
    @ViewBuilder var content: Content

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(L10n.string(titleKey, language: language))
                .sectionCaption()
                .padding(.horizontal, Theme.Spacing.xs)
            VStack(spacing: 0) {
                content
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }
}

/// A single-line text row inside a `FormSection`, hairline-separated from its neighbours.
struct FormFieldRow: View {
    let placeholderKey: L10n.Key
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var showsDivider = true
    var trailing: AnyView?

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                TextField(L10n.string(placeholderKey, language: language), text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .font(.body)
                if let trailing { trailing }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 13)

            if showsDivider {
                Divider().padding(.leading, Theme.Spacing.l)
            }
        }
    }
}

/// A label on the left and an inline menu picker on the right, as used for
/// Currency, Category and Payment Type.
struct FormPickerRow<Value: Hashable, Label: View>: View {
    let titleKey: L10n.Key
    @Binding var selection: Value
    let options: [Value]
    var showsDivider = true
    @ViewBuilder var label: (Value) -> Label

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.string(titleKey, language: language))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: Theme.Spacing.m)
                Menu {
                    Picker(L10n.string(titleKey, language: language), selection: $selection) {
                        ForEach(options, id: \.self) { option in
                            label(option).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 4) {
                        label(selection)
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 13)

            if showsDivider {
                Divider().padding(.leading, Theme.Spacing.l)
            }
        }
    }
}

/// The soft-green tinted button used by the scanner card.
struct SoftActionButton: View {
    let titleKey: L10n.Key
    let systemImage: String
    let action: () -> Void

    @Environment(\.appLanguage) private var language

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: systemImage)
                Text(L10n.string(titleKey, language: language))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(Theme.brandDeep)
            .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Solid green primary button ("Generate", "Update").
struct PrimaryButton: View {
    let titleKey: L10n.Key
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    @Environment(\.appLanguage) private var language

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(L10n.string(titleKey, language: language))
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(isEnabled ? Theme.brand : Theme.brand.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Muted destructive button ("Clear").
struct SubtleDestructiveButton: View {
    let titleKey: L10n.Key
    var systemImage: String?
    let action: () -> Void

    @Environment(\.appLanguage) private var language

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(L10n.string(titleKey, language: language))
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Theme.destructive)
            .background(Theme.destructiveSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
