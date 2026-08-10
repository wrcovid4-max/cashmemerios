import CoreData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lock: AppLockService
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language

    @State private var isShowingSignature = false
    @State private var isConfirmingDeleteAll = false
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var passcodeError: String?
    @State private var customCode = ""
    @State private var customSymbol = ""
    @State private var customName = ""
    @State private var backupURL: URL?
    @State private var isSharingBackup = false

    var body: some View {
        Form {
            // Grouped because a ViewBuilder accepts at most 10 children, and
            // exceeding it fails to type-check with a misleading error about
            // FormStyleConfiguration.
            Group {
                appearanceSection
                securitySection
                passcodeSection
                signatureSection
            }
            Group {
                customCurrencySection
                googleSection
                backupSection
                dataSection
                informationSection
                contactSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(L10n.string(.settings, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSignature) { signatureSheet }
        .sheet(isPresented: $isSharingBackup) {
            if let backupURL = backupURL { ShareSheet(items: [backupURL]) }
        }
        .alert(
            L10n.string(.deleteAllReceipts, language: language),
            isPresented: $isConfirmingDeleteAll
        ) {
            Button(L10n.string(.cancel, language: language), role: .cancel) {}
            Button(L10n.string(.delete, language: language), role: .destructive, action: deleteAllReceipts)
        } message: {
            Text(L10n.string(.deleteAllConfirm, language: language))
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section(L10n.string(.appearance, language: language)) {
            Toggle(isOn: Binding(
                get: { settings.language == .urdu },
                set: { settings.language = $0 ? .urdu : .english }
            )) {
                Text(L10n.string(.urduLanguage, language: language))
            }
            .tint(Theme.brand)

            Picker(L10n.string(.theme, language: language), selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(L10n.string(theme.key, language: language)).tag(theme)
                }
            }

            Picker(L10n.string(.currency, language: language), selection: $settings.defaultCurrencyCode) {
                ForEach(settings.availableCurrencies) { currency in
                    Text(currency.pickerLabel).tag(currency.code)
                }
            }
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(isOn: $settings.appLockEnabled) {
                Text(L10n.string(.appLock, language: language))
            }
            .tint(Theme.brand)

            Toggle(isOn: $settings.biometricsEnabled) {
                Text(L10n.string(.biometrics, language: language))
            }
            .tint(Theme.brand)
            .disabled(!lock.isBiometryAvailable)
        } header: {
            Text(L10n.string(.security, language: language))
        } footer: {
            Text(L10n.string(.appLockHint, language: language))
        }
    }

    private var passcodeSection: some View {
        Section {
            SecureField(L10n.string(.enterNewPasscode, language: language), text: $newPasscode)
                .keyboardType(.numberPad)
            SecureField(L10n.string(.confirmNewPasscode, language: language), text: $confirmPasscode)
                .keyboardType(.numberPad)

            if let passcodeError = passcodeError {
                Text(passcodeError)
                    .font(.caption)
                    .foregroundColor(Theme.destructive)
            }

            HStack(spacing: Theme.Spacing.m) {
                Button(L10n.string(.cancel, language: language)) {
                    newPasscode = ""
                    confirmPasscode = ""
                    passcodeError = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L10n.string(.update, language: language), action: updatePasscode)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .disabled(newPasscode.isEmpty)
            }

            if lock.hasCustomPasscode {
                Button(role: .destructive) {
                    lock.removePasscode()
                } label: {
                    Text(L10n.string(.removeSignature, language: language)
                        .replacingOccurrences(of: "Signature", with: "Passcode"))
                }
            }
        } header: {
            Text(L10n.string(.customPasscodeLock, language: language))
        } footer: {
            Text(L10n.string(.customPasscodeHint, language: language))
        }
    }

    private var signatureSection: some View {
        Section(L10n.string(.signature, language: language)) {
            Button(L10n.string(.createSignature, language: language)) {
                isShowingSignature = true
            }
            .foregroundColor(Theme.brand)

            if settings.defaultSignaturePNG != nil {
                Button(L10n.string(.removeSignature, language: language), role: .destructive) {
                    settings.defaultSignaturePNG = nil
                }
            }
        }
    }

    private var customCurrencySection: some View {
        Section(L10n.string(.customCurrency, language: language)) {
            TextField("Code (e.g. AUD)", text: $customCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("Symbol", text: $customSymbol)
            TextField(L10n.string(.name, language: language), text: $customName)

            Button(L10n.string(.addThisCurrency, language: language), action: addCustomCurrency)
                .foregroundColor(Theme.brand)
                .disabled(customCode.count < 3 || customSymbol.isEmpty)

            ForEach(settings.customCurrencies) { currency in
                HStack {
                    Text(currency.pickerLabel)
                    Spacer()
                    Button(role: .destructive) {
                        settings.customCurrencies.removeAll { $0.code == currency.code }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.destructive)
                }
            }
        }
    }

    private var googleSection: some View {
        Section {
            if settings.isSignedIntoGoogle {
                LabeledContent(L10n.string(.email, language: language)) {
                    Text(settings.googleAccountEmail ?? "")
                }
                Button(L10n.string(.signOut, language: language), role: .destructive) {
                    GoogleAuthService.shared.signOut(from: settings)
                }
            } else {
                Button {
                    GoogleAuthService.shared.signIn(into: settings)
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "g.circle.fill")
                        Text(L10n.string(.signInWithGoogle, language: language))
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, Theme.Spacing.m)
                    .foregroundColor(.white)
                    .background(Theme.googleBlue, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        } header: {
            Text(L10n.string(.googleSignIn, language: language))
        } footer: {
            Text(L10n.string(.googleSignInHint, language: language))
        }
    }

    private var backupSection: some View {
        Section(L10n.string(.backupAndRestore, language: language)) {
            Button {
                exportBackup()
            } label: {
                Label(L10n.string(.shareBackupFile, language: language), systemImage: "square.and.arrow.up")
                    .foregroundColor(Theme.brand)
            }
        }
    }

    private var dataSection: some View {
        Section(L10n.string(.dataManagement, language: language)) {
            Button(role: .destructive) {
                isConfirmingDeleteAll = true
            } label: {
                Label(L10n.string(.deleteAllReceipts, language: language), systemImage: "trash")
            }
        }
    }

    private var informationSection: some View {
        Section(L10n.string(.information, language: language)) {
            LabeledContent(L10n.string(.version, language: language)) {
                Text("\(AppInfo.version) (\(AppInfo.build))")
            }
            LabeledContent(L10n.string(.app, language: language)) {
                Text("Cash Memer – کیش میمر")
            }
        }
    }

    private var contactSection: some View {
        Section {
            ContactFooter()
        }
    }

    private var signatureSheet: some View {
        NavigationStack {
            ScrollView {
                SignaturePadView(
                    signaturePNG: Binding(
                        get: { settings.defaultSignaturePNG },
                        set: { settings.defaultSignaturePNG = $0 }
                    ),
                    saveAsDefault: .constant(true)
                )
                .padding(Theme.Spacing.l)
            }
            .background(Theme.background)
            .navigationTitle(L10n.string(.createSignature, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.done, language: language)) { isShowingSignature = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func updatePasscode() {
        guard newPasscode == confirmPasscode else {
            passcodeError = L10n.string(.passcodeMismatch, language: language)
            return
        }
        do {
            try lock.setPasscode(newPasscode)
            newPasscode = ""
            confirmPasscode = ""
            passcodeError = nil
        } catch {
            passcodeError = error.localizedDescription
        }
    }

    private func addCustomCurrency() {
        let code = customCode.uppercased()
        guard !settings.availableCurrencies.contains(where: { $0.code == code }) else { return }
        settings.customCurrencies.append(
            Currency(code: code, symbol: customSymbol, name: customName.isEmpty ? code : customName)
        )
        customCode = ""
        customSymbol = ""
        customName = ""
    }

    private func deleteAllReceipts() {
        // Batch delete keeps this fast on large stores, then the context is
        // reset so the UI does not hold on to deleted objects.
        let request = NSBatchDeleteRequest(fetchRequest: CDReceipt.fetchRequest())
        request.resultType = .resultTypeObjectIDs
        do {
            let result = try context.execute(request) as? NSBatchDeleteResult
            if let ids = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [context]
                )
            }
        } catch {
            assertionFailure("Batch delete failed: \(error)")
        }
    }

    private func exportBackup() {
        guard let url = try? BackupArchive.export(context: context) else { return }
        backupURL = url
        isSharingBackup = true
    }
}
