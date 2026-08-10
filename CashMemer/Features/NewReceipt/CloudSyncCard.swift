import CoreData
import SwiftUI

/// "Cloud Backup & Sync" — the linked Google account, plus the two things you can
/// ask for by hand.
///
/// Sync and Backup are deliberately not the same button. **Sync** pushes to
/// Firestore, needs a Google account, and is the thing that keeps this phone and
/// the Android app holding one dataset. **Backup** writes a self-contained JSON
/// file to this device, needs no account at all, and is the copy that survives
/// losing access to the cloud. They fail independently and are worth reaching for
/// at different moments, so they get different colours, different icons and
/// different enabled rules rather than one shared "upload" affordance.
struct CloudSyncCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    @ObservedObject private var sync = FirestoreSyncService.shared
    @Environment(\.managedObjectContext) private var context

    /// Shown under the header. Whether anything actually arrived is the first
    /// question when sync misbehaves, and reading it off the screen beats
    /// digging through the Xcode console.
    @FetchRequest(fetchRequest: CDReceipt.activeRequest()) private var storedReceipts: FetchedResults<CDReceipt>

    @State private var isBackingUp = false
    @State private var backupURL: URL?
    @State private var backupError: String?
    @State private var isSharingBackup = false

    private var isSyncing: Bool { sync.status == .syncing }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header

            Text("\(storedReceipts.count) \(L10n.string(.receiptsOnThisDevice, language: language))")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)

            if settings.isSignedIntoGoogle {
                accountRow
            } else {
                Text(L10n.string(.googleSignInHint, language: language))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            actionRow

            // One strip, never two at once — syncing wins if both somehow run.
            if isSyncing {
                ActivityStrip(
                    title: L10n.string(.syncing, language: language),
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: Theme.brandDeep
                )
            } else if isBackingUp {
                ActivityStrip(
                    title: L10n.string(.backingUp, language: language),
                    systemImage: "archivebox.fill",
                    tint: Theme.googleBlue
                )
            }

            if let backupURL = backupURL, !isBackingUp {
                backupReadyRow(url: backupURL)
            }

            if let backupError = backupError {
                failureText("\(L10n.string(.backupFailed, language: language)) — \(backupError)")
            }

            if case .failed(let message) = sync.status {
                failureText(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: isSyncing)
        .animation(.easeInOut(duration: 0.25), value: isBackingUp)
        .cardSurface()
        .sheet(isPresented: $isSharingBackup) {
            if let backupURL = backupURL { ShareSheet(items: [backupURL]) }
        }
    }

    // MARK: - Header

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

    // MARK: - Account

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

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Green, cloud, needs an account.
            CloudActionButton(
                title: L10n.string(.syncNow, language: language),
                systemImage: "arrow.triangle.2.circlepath",
                tint: Theme.brandDeep,
                fill: Theme.brandSoft,
                isBusy: isSyncing,
                isEnabled: settings.isSignedIntoGoogle && !isSyncing,
                action: syncNow
            )

            // Blue, box, works signed out — that difference is the point.
            CloudActionButton(
                title: L10n.string(.backUpNow, language: language),
                systemImage: "archivebox.fill",
                tint: Theme.googleBlue,
                fill: Theme.googleBlue.opacity(0.13),
                isBusy: isBackingUp,
                isEnabled: !isBackingUp,
                action: backUpNow
            )
        }
    }

    private func backupReadyRow(url: URL) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.googleBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.string(.backupReady, language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(url.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: Theme.Spacing.s)

            Button {
                isSharingBackup = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 30, height: 30)
                    .foregroundStyle(Theme.googleBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.shareBackupFile, language: language))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private func failureText(_ message: String) -> some View {
        Text(message)
            .font(.caption2)
            .foregroundStyle(Theme.destructive)
    }

    // MARK: - Behaviour

    /// Sync is automatic; this forces a full re-push for peace of mind.
    private func syncNow() {
        Task { @MainActor in await sync.pushAll(context: context) }
    }

    private func backUpNow() {
        guard !isBackingUp else { return }
        isBackingUp = true
        backupError = nil
        backupURL = nil

        Task { @MainActor in
            // Export runs on the main context because that is where the objects
            // live. It is fast enough for a personal receipt book that it would
            // otherwise finish before the strip renders, so hold the animation
            // briefly — a flash of "Backing up…" reads as a glitch, not progress.
            let floor = Task { try? await Task.sleep(nanoseconds: 700_000_000) }
            do {
                backupURL = try BackupArchive.export(context: context)
            } catch {
                backupError = error.localizedDescription
            }
            await floor.value
            isBackingUp = false
        }
    }

    private func signOut() {
        GoogleAuthService.shared.signOut(from: settings)
    }
}

// MARK: - Components

/// One of the two big actions. Swaps its icon for a spinner while busy so the
/// button itself reports progress, not just the strip below it.
private struct CloudActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let fill: Color
    let isBusy: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: systemImage)
                            .font(.title3)
                    }
                }
                .frame(height: 24)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .foregroundStyle(tint)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Animated "Syncing…" / "Backing up…" banner. The icon turns continuously and
/// the label breathes, so it is obvious at a glance that work is still going
/// rather than finished.
private struct ActivityStrip: View {
    let title: String
    let systemImage: String
    let tint: Color

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.1).repeatForever(autoreverses: false),
                    value: isAnimating
                )

            Text(title)
                .font(.caption.weight(.semibold))
                .opacity(isAnimating ? 1 : 0.45)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: Capsule())
        .onAppear { isAnimating = true }
    }
}
