import AppIntents
import CoreData
import Foundation

// MARK: - Create

/// "Add a receipt for 350 rupees at Chapters" — the whole flow without opening the app.
@available(iOS 16.0, *)
struct CreateReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Receipt"
    static var description = IntentDescription(
        "Creates a cash memo with a store name and amount.",
        categoryName: "Receipts"
    )
    /// Runs in the background so Siri can confirm without a UI round-trip.
    static var openAppWhenRun = false

    @Parameter(title: "Store", requestValueDialog: "Which store?")
    var store: String

    @Parameter(title: "Amount", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "Category", default: .shopping)
    var category: ReceiptCategoryAppEnum

    @Parameter(title: "Payment Method", default: .cash)
    var paymentMethod: PaymentMethodAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$category) receipt for \(\.$amount) at \(\.$store)") {
            \.$paymentMethod
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let settings = AppSettings()
        let context = PersistenceController.shared.container.viewContext

        let receipt = CDReceipt(context: context)
        receipt.id = UUID()
        receipt.number = CDReceipt.nextNumber(in: context)
        receipt.createdAt = Date()
        receipt.title = store
        receipt.storeName = store
        receipt.address = ""
        receipt.customerName = ""
        receipt.customerPhone = ""
        receipt.customerEmail = ""
        receipt.customerAddress = ""
        receipt.currencyCode = settings.defaultCurrencyCode
        receipt.categoryRaw = category.rawValue
        receipt.paymentMethodRaw = paymentMethod.rawValue
        receipt.discountTypeRaw = DiscountType.none.rawValue
        receipt.discountValue = 0
        receipt.taxPercent = 0
        receipt.cashGiven = 0
        receipt.note = MemoDefaults.noteOne
        receipt.notesPageTwo = ""
        receipt.signaturePNG = settings.defaultSignaturePNG
        receipt.isArchived = false
        receipt.issuedByName = settings.googleAccountName ?? ""
        receipt.issuedByEmail = settings.googleAccountEmail ?? ""

        let item = CDReceiptItem(context: context)
        item.id = UUID()
        item.name = store
        item.quantity = 1
        item.unitPrice = NSDecimalNumber(value: amount)
        item.sortIndex = 0
        item.receipt = receipt

        try context.save()

        let entity = ReceiptEntity(receipt: receipt)
        let formatted = CurrencyFormatter.string(receipt.totals.grandTotal, currency: receipt.currency)
        return .result(
            value: entity,
            dialog: IntentDialog("Saved a \(formatted) receipt for \(store).")
        )
    }
}

// MARK: - Scan

/// Opens the app straight into the scanner. Scanning needs the camera, so unlike
/// `CreateReceiptIntent` this one has to bring the app forward.
@available(iOS 16.0, *)
struct ScanReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Receipt"
    static var description = IntentDescription(
        "Opens the AI scanner to capture a paper receipt.",
        categoryName: "Receipts"
    )
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.pendingDestination = .scan
        return .result()
    }
}

// MARK: - Look up

@available(iOS 16.0, *)
struct FindReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Receipt"
    static var description = IntentDescription(
        "Looks up a saved receipt and reports its total.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$receipt)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let amount = String(format: "%.2f", receipt.total)
        return .result(
            value: receipt,
            dialog: IntentDialog("\(receipt.store) — \(receipt.currencyCode) \(amount) on \(receipt.date.formatted(date: .abbreviated, time: .omitted)).")
        )
    }
}

// MARK: - Daily total

@available(iOS 16.0, *)
struct TodaysTotalIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Total"
    static var description = IntentDescription(
        "Reports how much has been receipted today.",
        categoryName: "Dashboard"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let settings = AppSettings()
        let context = PersistenceController.shared.container.viewContext

        guard let range = DashboardPeriod.today.range() else {
            return .result(value: 0, dialog: IntentDialog("No receipts today."))
        }
        let receipts = try context.fetch(CDReceipt.request(in: range))
        let total = receipts.reduce(Decimal.zero) { $0 + $1.totals.grandTotal }
        let formatted = CurrencyFormatter.string(total, currency: settings.defaultCurrency)
        let count = receipts.count

        return .result(
            value: NSDecimalNumber(decimal: total).doubleValue,
            dialog: IntentDialog("\(count) receipts today, totalling \(formatted).")
        )
    }
}

// MARK: - Open

@available(iOS 16.0, *)
struct OpenDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Dashboard"
    static var description = IntentDescription("Opens the Cash Memer dashboard.", categoryName: "Dashboard")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.pendingDestination = .dashboard
        return .result()
    }
}

// MARK: - App enums

@available(iOS 16.0, *)
enum ReceiptCategoryAppEnum: String, AppEnum {
    case shopping, groceries, food, fuel, travel, utilities, health, education, services, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [ReceiptCategoryAppEnum: DisplayRepresentation] = [
        .shopping: "Shopping",
        .groceries: "Groceries",
        .food: "Food",
        .fuel: "Fuel",
        .travel: "Travel",
        .utilities: "Utilities",
        .health: "Health",
        .education: "Education",
        .services: "Services",
        .other: "Other"
    ]
}

@available(iOS 16.0, *)
enum PaymentMethodAppEnum: String, AppEnum {
    case cash, applePay, card, bankTransfer, easypaisa, jazzcash, credit

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Payment Method"

    static var caseDisplayRepresentations: [PaymentMethodAppEnum: DisplayRepresentation] = [
        .cash: "Cash",
        .applePay: "Apple Pay",
        .card: "Card",
        .bankTransfer: "Bank Transfer",
        .easypaisa: "Easypaisa",
        .jazzcash: "JazzCash",
        .credit: "Credit"
    ]
}

// MARK: - App Shortcuts

/// Phrases Siri recognises without the user configuring anything. `applicationName`
/// is required in every phrase, so each one reads naturally with "Cash Memer".
@available(iOS 16.0, *)
struct CashMemerShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .green

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Scan a receipt with \(.applicationName)",
                "Scan a memo in \(.applicationName)",
                "New \(.applicationName) scan"
            ],
            shortTitle: "Scan Receipt",
            systemImageName: "viewfinder"
        )
        AppShortcut(
            intent: CreateReceiptIntent(),
            phrases: [
                "Create a receipt in \(.applicationName)",
                "Add a \(.applicationName) memo",
                "New receipt in \(.applicationName)"
            ],
            shortTitle: "Create Receipt",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: TodaysTotalIntent(),
            phrases: [
                "What is my total in \(.applicationName)",
                "Today's total in \(.applicationName)",
                "How much did I spend in \(.applicationName)"
            ],
            shortTitle: "Today's Total",
            systemImageName: "sum"
        )
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open \(.applicationName) dashboard",
                "Show my \(.applicationName) dashboard"
            ],
            shortTitle: "Open Dashboard",
            systemImageName: "chart.bar.fill"
        )
    }
}
