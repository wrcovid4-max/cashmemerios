import Combine
import FirebaseAuth
import Foundation
import GoogleSignIn
import UIKit

/// Google Sign-In, bridged into Firebase Auth.
///
/// The Google credential is exchanged for a Firebase one so Firestore sees the
/// same uid the Android app signs in as — that shared uid is what makes the two
/// apps one dataset. It also stamps the issuing account onto each memo.
///
/// The client ID is read from `GoogleService-Info.plist`; if that file has not been
/// added to the target yet, every entry point fails with a readable message rather
/// than trapping.
@MainActor
final class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    @Published private(set) var isBusy = false
    @Published private(set) var lastError: String?

    private init() {}

    var isConfigured: Bool { APIKeys.isGoogleSignInConfigured }

    /// Restores a previous session on launch so the user is not asked again.
    func restorePreviousSignIn(into settings: AppSettings) {
        guard isConfigured else { return }
        configureIfNeeded()

        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            guard let user = user else { return }
            self?.apply(user, to: settings)
            self?.linkToFirebase(user, settings: settings)
        }
    }

    func signIn(into settings: AppSettings) {
        guard isConfigured else {
            lastError = "Add GoogleService-Info.plist to the CashMemer target to enable Google Sign-In."
            return
        }
        guard let presenter = Self.topViewController() else {
            lastError = "No window is available to present the sign-in sheet."
            return
        }

        configureIfNeeded()
        isBusy = true

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            guard let self = self else { return }
            self.isBusy = false

            if let error = error {
                // A user-cancelled sheet is not worth surfacing as a failure.
                let nsError = error as NSError
                if nsError.code != GIDSignInError.canceled.rawValue {
                    self.lastError = error.localizedDescription
                }
                return
            }

            guard let user = result?.user else { return }
            self.lastError = nil
            self.apply(user, to: settings)
            self.linkToFirebase(user, settings: settings)
        }
    }

    func signOut(from settings: AppSettings) {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        FirestoreSyncService.shared.stop()
        settings.googleAccountEmail = nil
        settings.googleAccountName = nil
    }

    /// Signs into Firebase with the Google credential, then starts syncing.
    private func linkToFirebase(_ user: GIDGoogleUser, settings: AppSettings) {
        guard let idToken = user.idToken?.tokenString else { return }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        Auth.auth().signIn(with: credential) { [weak self] _, error in
            if let error = error {
                self?.lastError = error.localizedDescription
                return
            }
            let context = PersistenceController.shared.container.viewContext
            // Settings ride along so preferences sync too — they used to live
            // only in UserDefaults and died with the device.
            FirestoreSyncService.shared.start(context: context, settings: settings)
        }
    }

    /// Routes the callback URL Google opens the app with.
    @discardableResult
    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Private

    private func configureIfNeeded() {
        guard GIDSignIn.sharedInstance.configuration == nil,
              let clientID = APIKeys.googleClientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    private func apply(_ user: GIDGoogleUser, to settings: AppSettings) {
        settings.googleAccountEmail = user.profile?.email
        settings.googleAccountName = user.profile?.name
    }

    /// Walks the active scene down to whatever is actually on screen.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        guard let root = scene?.keyWindow?.rootViewController else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first { $0.isKeyWindow } ?? windows.first
    }
}
