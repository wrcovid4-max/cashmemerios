import Foundation
import Combine
import LocalAuthentication

/// Gates the app behind Face ID / Touch ID with a stored passcode as the fallback.
final class AppLockService: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var lastError: String?

    private let keychainAccount = "com.cashmemer.applock.passcode"

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false
        lastError = nil
    }

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var isBiometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Prompts for Face ID / Touch ID. Falls back to the device passcode when
    /// biometrics are unavailable, so a user is never locked out of their own data.
    @MainActor
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        let policy: LAPolicy = isBiometryAvailable
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success { unlock() }
            return success
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Custom passcode

    var hasCustomPasscode: Bool { storedPasscode != nil }

    func setPasscode(_ passcode: String) throws {
        guard passcode.count >= 4 else { throw LockError.passcodeTooShort }
        try Keychain.set(Data(passcode.utf8), account: keychainAccount)
    }

    func removePasscode() {
        Keychain.remove(account: keychainAccount)
    }

    func validate(passcode: String) -> Bool {
        guard let stored = storedPasscode else { return false }
        // Constant-time comparison so a wrong guess leaks nothing through timing.
        let candidate = Data(passcode.utf8)
        guard candidate.count == stored.count else { return false }
        var difference: UInt8 = 0
        for (lhs, rhs) in zip(candidate, stored) { difference |= lhs ^ rhs }
        if difference == 0 {
            unlock()
            return true
        }
        return false
    }

    private var storedPasscode: Data? {
        Keychain.get(account: keychainAccount)
    }

    enum LockError: LocalizedError {
        case passcodeTooShort

        var errorDescription: String? {
            switch self {
            case .passcodeTooShort: return "Passcode must be at least 4 digits."
            }
        }
    }
}

/// Minimal Keychain wrapper for the single secret this app stores.
enum Keychain {
    private static let service = "com.cashmemer.app"

    static func set(_ data: Data, account: String) throws {
        remove(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    static func get(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func remove(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case unhandled(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status): return "Keychain error \(status)."
            }
        }
    }
}
