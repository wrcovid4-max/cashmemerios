import CoreData
import CoreSpotlight
import Foundation

/// The Core Data stack, shared by the app, the widget extension and the intents.
///
/// The store lives in an App Group container so the Live Activity, App Intents and
/// widgets all read the same receipts the app writes.
struct PersistenceController {
    static let appGroupID = AppSettings.appGroupID

    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        controller.seedPreviewData()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CashMemer")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("CashMemer.xcdatamodeld is missing from the target.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            description.url = groupURL.appendingPathComponent("CashMemer.sqlite")
        }

        // History tracking is what lets Spotlight donation and the widget see
        // changes made by another process.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Both default to true; stated outright because the whole model-versioning
        // arrangement depends on them.
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        var loadError: NSError?
        container.loadPersistentStores { _, error in
            loadError = error as NSError?
        }

        // A store that will not open used to hit `assertionFailure`, which traps
        // in Debug — turning a recoverable problem into a crash on every launch,
        // with no way out but deleting the app. Rebuild instead. Receipts live in
        // Firestore and come back on the next sync, so a rebuilt store costs far
        // less than an app that cannot start.
        if let loadError = loadError, !inMemory, let storeURL = description.url {
            NSLog("Cash Memer: rebuilding the local store, it could not be opened — \(loadError)")
            Self.removeStoreFiles(at: storeURL)

            var retryError: NSError?
            container.loadPersistentStores { _, error in
                retryError = error as NSError?
            }
            if let retryError = retryError {
                assertionFailure("Unable to open the Cash Memer store: \(retryError), \(retryError.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        if !inMemory {
            spotlightIndexer = ReceiptSpotlightDelegate(
                forStoreWith: description,
                coordinator: container.persistentStoreCoordinator
            )
            spotlightIndexer?.startSpotlightIndexing()
        }
    }

    /// Retained so indexing keeps running for the process lifetime.
    private var spotlightIndexer: ReceiptSpotlightDelegate?

    /// SQLite keeps its write-ahead log and shared memory beside the database.
    /// Removing only the `.sqlite` leaves those two behind, and the store fails to
    /// open again for a different reason.
    private static func removeStoreFiles(at url: URL) {
        let manager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if manager.fileExists(atPath: path) {
                try? manager.removeItem(atPath: path)
            }
        }
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save: \(error)")
        }
    }

    /// Background context for imports and bulk deletes.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    private func seedPreviewData() {
        let context = container.viewContext

        let member = CDMember(context: context)
        member.id = UUID()
        member.name = "Umer Butt"
        member.phone = "0304 4545431"
        member.email = "wr.covid.4@gmail.com"
        member.notes = ""
        member.createdAt = Date()

        let receipt = CDReceipt(context: context)
        receipt.id = UUID()
        receipt.number = "41"
        receipt.createdAt = Date()
        receipt.title = "Chapters"
        receipt.storeName = "Chapters"
        receipt.address = "281, Sector FF Dha Phase 4, Lahore, Pakistan"
        receipt.latitude = NSNumber(value: 31.464347)
        receipt.longitude = NSNumber(value: 74.390228)
        receipt.memberID = member.id
        receipt.customerName = "Umer Butt"
        receipt.customerPhone = "0304 4545431"
        receipt.customerEmail = "wr.covid.4@gmail.com"
        receipt.customerAddress = "265/1, Sector L, Phase 1, Street 160, DHA Lahore"
        receipt.currencyCode = Currency.pkr.code
        receipt.categoryRaw = ReceiptCategory.shopping.rawValue
        receipt.paymentMethodRaw = PaymentMethod.cash.rawValue
        receipt.discountTypeRaw = DiscountType.none.rawValue
        receipt.discountValue = 0
        receipt.taxPercent = 0
        receipt.cashGiven = 0
        receipt.note = "Thank you for shopping!"
        receipt.notesPageTwo = ""
        receipt.isArchived = false
        receipt.issuedByName = "Umer Butt"
        receipt.issuedByEmail = "wr.covid.4@gmail.com"

        let item = CDReceiptItem(context: context)
        item.id = UUID()
        item.name = "Piano Ball Point"
        item.quantity = 1
        item.unitPrice = NSDecimalNumber(value: 350)
        item.sortIndex = 0
        item.receipt = receipt

        try? context.save()
    }
}

// MARK: - Fetch requests

extension CDReceipt {
    static func activeRequest(search: String = "") -> NSFetchRequest<CDReceipt> {
        let request = CDReceipt.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDReceipt.createdAt, ascending: false)]

        let notArchived = NSPredicate(format: "isArchived == NO")
        if search.isEmpty {
            request.predicate = notArchived
        } else {
            let matches = NSPredicate(
                format: "storeName CONTAINS[cd] %@ OR title CONTAINS[cd] %@ OR customerName CONTAINS[cd] %@ OR number CONTAINS[cd] %@",
                search, search, search, search
            )
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [notArchived, matches])
        }
        return request
    }

    static func archivedRequest() -> NSFetchRequest<CDReceipt> {
        let request = CDReceipt.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDReceipt.createdAt, ascending: false)]
        return request
    }

    /// Receipts created inside `range`, oldest first — the shape the charts want.
    static func request(in range: Range<Date>) -> NSFetchRequest<CDReceipt> {
        let request = CDReceipt.fetchRequest()
        request.predicate = NSPredicate(
            format: "isArchived == NO AND createdAt >= %@ AND createdAt < %@",
            range.lowerBound as NSDate,
            range.upperBound as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDReceipt.createdAt, ascending: true)]
        return request
    }

    static func request(numberOrID text: String) -> NSFetchRequest<CDReceipt> {
        let request = CDReceipt.fetchRequest()
        if let uuid = UUID(uuidString: text) {
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "number ==[c] %@", text)
        }
        request.fetchLimit = 1
        return request
    }
}

extension CDMember {
    static func allRequest() -> NSFetchRequest<CDMember> {
        let request = CDMember.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMember.name, ascending: true)]
        return request
    }
}
