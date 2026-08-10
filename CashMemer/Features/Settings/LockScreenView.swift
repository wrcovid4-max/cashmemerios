import LocalAuthentication
import SwiftUI

/// Full-screen gate shown while App Lock is armed.
struct LockScreenView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLockService
    @Environment(\.appLanguage) private var language

    @State private var passcode = ""
    @State private var showsPasscodeEntry = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(7)
                            .background(Theme.brand, in: Circle())
                            .offset(x: 6, y: 6)
                    }

                Text(L10n.string(.appName, language: language))
                    .font(.title2.weight(.bold))
                    .foregroundColor(Theme.textPrimary)

                Text(L10n.string(.appLock, language: language))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)

                if showsPasscodeEntry {
                    passcodeEntry
                } else {
                    PrimaryButton(titleKey: .appLock, systemImage: biometrySymbol, action: authenticate)
                        .frame(maxWidth: 260)

                    if lock.hasCustomPasscode {
                        Button(L10n.string(.customPasscodeLock, language: language)) {
                            showsPasscodeEntry = true
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.brand)
                    }
                }

                if let error = error ?? lock.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.destructive)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .task { await attemptBiometricsOnAppear() }
    }

    private var passcodeEntry: some View {
        VStack(spacing: Theme.Spacing.m) {
            SecureField(L10n.string(.enterNewPasscode, language: language), text: $passcode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textContentType(.password)
                .padding()
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .frame(maxWidth: 260)

            PrimaryButton(titleKey: .ok, isEnabled: passcode.count >= 4) {
                if !lock.validate(passcode: passcode) {
                    error = L10n.string(.passcodeMismatch, language: language)
                    passcode = ""
                }
            }
            .frame(maxWidth: 260)
        }
    }

    private var biometrySymbol: String {
        switch lock.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "key.fill"
        }
    }

    @MainActor
    private func authenticate() {
        Task { @MainActor in
            error = nil
            let ok = await lock.authenticate(reason: L10n.string(.appLockHint, language: language))
            // Fall back to the stored passcode rather than stranding the user.
            if !ok && lock.hasCustomPasscode { showsPasscodeEntry = true }
        }
    }

    private func attemptBiometricsOnAppear() async {
        guard settings.biometricsEnabled, lock.isBiometryAvailable else { return }
        _ = await lock.authenticate(reason: L10n.string(.appLockHint, language: language))
    }
}
