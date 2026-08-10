import CoreData
import SwiftUI

/// "Cloud Backup & Sync" — shows the linked Google account, or prompts to connect one.
struct CloudSyncCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    @ObservedObject private var sync = FirestoreSyncService.shared
    @Environment(\.managedObjectContext) private var context

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

            if case .failed(let message) = sync.status {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.destructive)
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
        Label(statusText, systemImage: statusIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusBackground, in: Capsule())
    }

    private var statusText: String {
        switch sync.status {
        case .signedOut: return L10n.string(.notConnected, language: language)
        case .idle: return L10n.string(.connected, language: language)
        case .syncing: return L10n.string(.syncing, language: language)
        case .synced(let date): return date.formatted(date: .omitted, time: .shortened)
        case .failed: return L10n.string(.syncFailed, language: language)
        }
    }

    private var statusIcon: String {
        switch sync.status {
        case .signedOut: return "cloud.slash"
        case .idle: return "cloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud.fill"
        case .failed: return "exclamationmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        switch sync.status {
        case .failed: return Theme.destructive
        case .signedOut: return Theme.textSecondary
        default: return Theme.brandDeep
        }
    }

    private var statusBackground: Color {
        switch sync.status {
        case .failed: return Theme.destructiveSoft
        case .signedOut: return Theme.cardAlt
        default: return Theme.brandSoft
        }
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
                    if sync.status == .syncing {
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

    /// Sync is automatic; this forces a full re-push for peace of mind.
    private func upload() {
        Task { await sync.pushAll(context: context) }
    }

    private func signOut() {
        GoogleAuthService.shared.signOut(from: settings)
    }
}
