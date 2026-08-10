import Combine
import CoreData
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Keeps Core Data and Firestore in step automatically.
///
/// Documents live under `users/{uid}`, and the uid is the Firebase Auth user the
/// Google account maps to — the same uid the Android app signs in as, which is
/// what makes the two apps one dataset rather than two.
///
/// Conflicts are settled last-write-wins on `updatedAt`. That is the right trade
/// for a single person's receipt book: edits from two devices at once are rare,
/// and a silently discarded newer edit would be worse than a merge dialog nobody
/// wants to read.
@MainActor
final class FirestoreSyncService: ObservableObject {
    static let shared = FirestoreSyncService()

    enum Status: Equatable {
        case signedOut
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .signedOut

    private let database = Firestore.firestore()
    private var receiptListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?
    private var saveObserver: NSObjectProtocol?
    private var context: NSManagedObjectContext?

    /// Set while remote documents are being written into Core Data, so the save
    /// they trigger is not echoed straight back to Firestore.
    ///
    /// A lock-guarded box rather than a plain `Bool`, for two reasons that are
    /// really the same reason. Core Data posts `NSManagedObjectContextDidSave`
    /// from inside `context.save()`, and the observer closure is non-isolated as
    /// far as the compiler is concerned — a main-actor property could only be
    /// read after hopping to the main actor, which is a run-loop turn too late.
    /// By then the flag has been cleared and every inbound change echoes
    /// straight back out to Firestore. Being `Sendable`, this reads correctly
    /// from the observer without a hop.
    private nonisolated let applyingRemote = RemoteApplyFlag()

    private init() {}

    private var uid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Lifecycle

    func start(context: NSManagedObjectContext) {
        self.context = context

        guard let uid = uid else {
            status = .signedOut
            return
        }

        stopListening()
        status = .syncing

        listenForReceipts(uid: uid, context: context)
        listenForMembers(uid: uid, context: context)
        observeLocalSaves(context: context)

        // Anything created before sign-in still needs to reach the cloud.
        Task { await pushAll(context: context) }
    }

    func stop() {
        stopListening()
        status = .signedOut
    }

    private func stopListening() {
        receiptListener?.remove()
        memberListener?.remove()
        receiptListener = nil
        memberListener = nil
        if let saveObserver = saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
            self.saveObserver = nil
        }
    }

    // MARK: - Remote → local

    private func listenForReceipts(uid: String, context: NSManagedObjectContext) {
        receiptListener = database.collection("users").document(uid).collection("receipts")
            .addSnapshotListener { [weak self] snapshot, error in
                // Firestore calls back on the main queue, but that is a runtime
                // promise the compiler cannot see, so hop explicitly.
                Task { @MainActor in
                    guard let self = self else { return }
                    if let error = error {
                        self.status = .failed(error.localizedDescription)
                        return
                    }
                    guard let snapshot = snapshot else { return }
                    self.applyReceiptChanges(snapshot.documentChanges, context: context)
                }
            }
    }

    private func applyReceiptChanges(_ changes: [DocumentChange], context: NSManagedObjectContext) {
        guard !changes.isEmpty else {
            status = .synced(Date())
            return
        }

        applyingRemote.isSet = true
        defer {
            applyingRemote.isSet = false
            status = .synced(Date())
        }

        for change in changes {
            let document = change.document.data()
            let documentID = change.document.documentID

            // Android and iOS write different shapes into the same account, so
            // each document is identified by what it looks like rather than by
            // where it is. Android's `id` is the printed receipt number, not a
            // UUID, so its local id is derived from the Firestore document id.
            let isAndroid = AndroidReceiptDocument.matches(document)
            let id: UUID
            if isAndroid {
                id = AndroidReceiptDocument.localID(forDocument: documentID)
            } else if let parsed = (document["id"] as? String).flatMap(UUID.init(uuidString:)) {
                id = parsed
            } else {
                continue
            }

            let request = CDReceipt.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let existing = try? context.fetch(request).first

            switch change.type {
            case .removed:
                if let existing = existing { context.delete(existing) }
            case .added, .modified:
                // A local edit newer than the remote one wins and is pushed back.
                // Android's timestamps are epoch milliseconds; read as seconds
                // they land in the year 58,000 and every local edit would lose.
                let remoteDate = isAndroid
                    ? AndroidReceiptDocument.date(document["lastModified"]) ?? .distantPast
                    : ReceiptDocument.date(document["updatedAt"]) ?? .distantPast
                if let existing = existing, let localDate = existing.updatedAt, localDate > remoteDate {
                    Task { await push(receipt: existing) }
                    continue
                }
                let receipt = existing ?? CDReceipt(context: context)
                if existing == nil { receipt.id = id }
                if isAndroid {
                    AndroidReceiptDocument.apply(
                        document,
                        to: receipt,
                        documentID: documentID,
                        in: context
                    )
                } else {
                    ReceiptDocument.apply(document, to: receipt, in: context)
                }
            }
        }

        saveQuietly(context)
    }

    private func listenForMembers(uid: String, context: NSManagedObjectContext) {
        memberListener = database.collection("users").document(uid).collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self, error == nil, let snapshot = snapshot else { return }
                    self.applyMemberChanges(snapshot.documentChanges, context: context)
                }
            }
    }

    private func applyMemberChanges(_ changes: [DocumentChange], context: NSManagedObjectContext) {
        guard !changes.isEmpty else { return }

        applyingRemote.isSet = true
        defer { applyingRemote.isSet = false }

        for change in changes {
            let document = change.document.data()
            guard let id = (document["id"] as? String).flatMap(UUID.init(uuidString:)) else { continue }

            let request = CDMember.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let existing = try? context.fetch(request).first

            if change.type == .removed {
                if let existing = existing { context.delete(existing) }
                continue
            }

            let remoteDate = ReceiptDocument.date(document["updatedAt"]) ?? .distantPast
            if let existing = existing, let localDate = existing.updatedAt, localDate > remoteDate {
                continue
            }
            let member = existing ?? CDMember(context: context)
            if existing == nil { member.id = id }
            ReceiptDocument.apply(document, to: member)
        }

        saveQuietly(context)
    }

    private func saveQuietly(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Local → remote

    private func observeLocalSaves(context: NSManagedObjectContext) {
        // `queue: nil` is deliberate. It makes the block run synchronously on the
        // thread that posted the save, which is the only point at which
        // `applyingRemote` still reflects the save being observed. Handing this
        // to `.main` queues the block for the next run-loop turn — by then the
        // flag has been cleared, the guard below never fires, and every receipt
        // arriving from Android is pushed straight back to Firestore.
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: nil
        ) { [weak self] notification in
            guard let self = self, !self.applyingRemote.isSet else { return }
            Task { @MainActor in await self.pushChanges(from: notification) }
        }
    }

    private func pushChanges(from notification: Notification) async {
        let info = notification.userInfo ?? [:]
        let inserted = info[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = info[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = info[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

        for object in inserted.union(updated) {
            if let receipt = object as? CDReceipt {
                await push(receipt: receipt)
            } else if let member = object as? CDMember {
                await push(member: member)
            } else if let item = object as? CDReceiptItem, let parent = item.receipt {
                // Items have no document of their own; they ride with the receipt.
                await push(receipt: parent)
            }
        }

        for object in deleted {
            if let receipt = object as? CDReceipt {
                await delete(documentID: receipt.remoteDocID ?? receipt.id.uuidString, from: "receipts")
            } else if let member = object as? CDMember {
                await delete(documentID: member.id.uuidString, from: "members")
            }
        }
    }

    @discardableResult
    func push(receipt: CDReceipt) async -> Bool {
        guard let uid = uid else { return false }

        // Stamp the edit so the other device can tell which copy is newer.
        if receipt.updatedAt == nil || !applyingRemote.isSet {
            receipt.updatedAt = Date()
        }

        // A receipt that arrived from Android goes back to its own document, in
        // Android's shape. Writing an iOS-shaped copy under a fresh UUID would
        // leave the phone's original untouched and the memo duplicated.
        let payload: [String: Any]
        let id: String
        if let remoteDocID = receipt.remoteDocID, !remoteDocID.isEmpty {
            payload = AndroidReceiptDocument.dictionary(from: receipt)
            id = remoteDocID
        } else {
            payload = ReceiptDocument.dictionary(from: receipt)
            id = receipt.id.uuidString
        }

        do {
            try await database.collection("users").document(uid)
                .collection("receipts").document(id).setData(payload, merge: false)
            status = .synced(Date())
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func push(member: CDMember) async -> Bool {
        guard let uid = uid else { return false }

        if member.updatedAt == nil || !applyingRemote.isSet {
            member.updatedAt = Date()
        }
        let payload = ReceiptDocument.dictionary(from: member)

        do {
            try await database.collection("users").document(uid)
                .collection("members").document(member.id.uuidString).setData(payload, merge: false)
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    private func delete(documentID: String, from collection: String) async {
        guard let uid = uid, !documentID.isEmpty else { return }
        try? await database.collection("users").document(uid)
            .collection(collection).document(documentID).delete()
    }

    /// Full push, used on first sign-in and from the manual upload button.
    func pushAll(context: NSManagedObjectContext) async {
        guard uid != nil else { return }
        status = .syncing

        let receipts = (try? context.fetch(CDReceipt.fetchRequest())) ?? []
        for receipt in receipts {
            await push(receipt: receipt)
        }

        let members = (try? context.fetch(CDMember.allRequest())) ?? []
        for member in members {
            await push(member: member)
        }

        status = .synced(Date())
    }
}

/// A `Bool` readable and writable from any isolation context.
///
/// Exists so `FirestoreSyncService.applyingRemote` can be checked synchronously
/// from the Core Data save notification, which arrives in a non-isolated closure.
private final class RemoteApplyFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}
