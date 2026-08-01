import SwiftUI

/// "Cloud Backup & Sync" — shows the linked Google account, or prompts to connect one.
struct CloudSyncCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    @State private var isUploading = false
    @State private var lastUploadedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header

            if settings.isSignedIntoGoogle {
                accountRow
            } else {
                Text(L10n.string(.googleSignInHint, language: language))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var header: some View {
        HStack {
            Label {
                Text(L10n.string(.cloudBackupAndSync, language: language))
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            } icon: {
                Image(systemName: "icloud.fill")
                    .foregroundStyle(Theme.brand)
            }
            Spacer(minLength: Theme.Spacing.s)
            statusPill
        }
    }

    private var statusPill: some View {
        Label(
            L10n.string(settings.isSignedIntoGoogle ? .connected : .notConnected, language: language),
            systemImage: settings.isSignedIntoGoogle ? "cloud.fill" : "cloud.slash"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(settings.isSignedIntoGoogle ? Theme.brandDeep : Theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            (settings.isSignedIntoGoogle ? Theme.brandSoft : Theme.cardAlt),
            in: Capsule()
        )
    }

    private var accountRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Circle()
                .fill(Theme.brandSoft)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initials)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.brandDeep)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(settings.googleAccountName ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(settings.googleAccountEmail ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)

            Button(action: upload) {
                Group {
                    if isUploading {
                        ProgressView()
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                    }
                }
                .frame(width: 34, height: 34)
                .foregroundStyle(Theme.brand)
                .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.uploadBackup, language: language))

            Button(action: signOut) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .frame(width: 34, height: 34)
                    .foregroundStyle(Theme.destructive)
                    .background(Theme.destructiveSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.signOut, language: language))
        }
    }

    private var initials: String {
        let source = settings.googleAccountName ?? settings.googleAccountEmail ?? "?"
        return String(source.prefix(1)).uppercased()
    }

    private func upload() {
        isUploading = true
        Task {
            // Drive upload progress once a Drive/iCloud backend is wired up; the
            // local export path already produces the file this would send.
            try? await Task.sleep(for: .seconds(1))
            lastUploadedAt = Date()
            isUploading = false
        }
    }

    private func signOut() {
        settings.googleAccountEmail = nil
        settings.googleAccountName = nil
    }
}
