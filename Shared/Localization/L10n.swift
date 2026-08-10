import Foundation
import SwiftUI

/// In-app localization.
///
/// The ENG ⇄ اردو toggle has to flip the whole UI *without* an app relaunch, which
/// rules out `NSLocalizedString` and the bundle-swap tricks around it. Strings live
/// in Swift dictionaries instead, so switching language is just a published change.
enum L10n {
    enum Key: String, CaseIterable {
        // Brand
        case appName, appTagline

        // Navigation
        case newReceipt, history, dashboard, scan, rates, settings, members, archive, more

        // New Receipt
        case aiReceiptScanner, gallery, camera, scanBarcode, viewScanHistory
        case receiptDetails, titleField, placeStoreName, address, locationAddressGPS
        case currency, category, paymentType, selectMember
        case customerName, customerPhone, customerEmail
        case addItems, itemName, quantity, price, unitPrice, total, item
        case discountAndTax, discountType, taxPercentOptional
        case notes, notesPageTwo, livePreview
        case digitalSignature, signatureCaptured, signatureHint, saveAsDefaultSignature
        case clearAndRedraw, clear, generate

        // Memo
        case cashMemo, receiptNo, date, time, method, customer, subtotal, grandTotal
        case discount, tax, cashGiven, changeAmount, note, savedLocation, gps
        case authorizedSignature, scanQRForDetails, thankYouForShopping

        // History / archive
        case searchReceipts, noReceiptsYet, noReceiptsHint, archived, unarchive, delete, share, duplicate

        // Dashboard
        case periodToday, periodWeek, periodMonth, periodYear, periodCustom
        case invoices, topStore, thisMonth, avgReceipt, totalItems, topCategory
        case revenueTrend, insights, notEnoughData, noDataForPeriod
        case liveExchangeRates, updatedAt, refresh

        // Quick overview (sidebar)
        case quickOverview, todaysSales, todaysRevenue, totalProducts, scansToday
        case online, offline, rateAPI, weather, ratesAt

        // Members
        case membersDirectory, addMember, editMember, exportMembers, name, phone, email
        case noMembersYet, noMembersHint

        // Settings
        case appearance, urduLanguage, theme, themeSystem, themeLight, themeDark
        case security, appLock, appLockHint, biometrics
        case customPasscodeLock, customPasscodeHint, enterNewPasscode, confirmNewPasscode
        case cancel, update, passcodeMismatch, passcodeTooShort
        case signature, createSignature, removeSignature
        case customCurrency, addThisCurrency
        case googleSignIn, googleSignInHint, signInWithGoogle, signOut
        case backupAndRestore, uploadBackup, shareBackupFile, restoreFromBackup
        case dataManagement, deleteAllReceipts, deleteAllConfirm
        case information, version, app
        case contactUs, mail, web, social, contactResponseNote

        // Categories
        case categoryShopping, categoryGroceries, categoryFood, categoryFuel, categoryTravel
        case categoryUtilities, categoryHealth, categoryEducation, categoryServices, categoryOther

        // Payment methods
        case methodCash, methodApplePay, methodCard, methodBankTransfer
        case methodEasypaisa, methodJazzcash, methodCredit

        // Discounts
        case discountNone, discountPercentage, discountFixed

        // Watch
        case openOnIPhoneToSync, openOnIPhoneToSyncRates, syncedJustNow

        // Two-page memo
        case issuedBy, accountEmail
        case pageTwo, placeStore, customerDetails, customerAddress
        case issuerAccount, notePageTwoLabel, each, noteTwoPrivateHint

        // Misc
        case cloudBackupAndSync, connected, notConnected, syncing, syncFailed, done, save, retry, ok
        case syncNow, backUpNow, backingUp, backupReady, backupFailed, backupNeedsNoAccount
        case scannerHint, signHere, applePencilOnly
        case totalWithoutDiscount, totalWithoutTax, searchCurrencies, iranianToman
        case currencyCodeExample, currencySymbol, removePasscode, clearSignature
        case receiptsOnThisDevice
    }

    static func string(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english: return english[key] ?? key.rawValue
        case .urdu: return urdu[key] ?? english[key] ?? key.rawValue
        }
    }
}

// MARK: - Environment plumbing

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

extension View {
    /// Applies the language *and* mirrors the layout for Urdu in one call.
    func appLanguage(_ language: AppLanguage) -> some View {
        environment(\.appLanguage, language)
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, language.locale)
    }
}

/// `Text(.dashboard)` — reads the active language straight out of the environment.
struct LocalizedText: View {
    @Environment(\.appLanguage) private var language
    private let key: L10n.Key

    init(_ key: L10n.Key) { self.key = key }

    var body: some View {
        Text(L10n.string(key, language: language))
    }
}

extension Text {
    init(_ key: L10n.Key, language: AppLanguage) {
        self.init(L10n.string(key, language: language))
    }
}
