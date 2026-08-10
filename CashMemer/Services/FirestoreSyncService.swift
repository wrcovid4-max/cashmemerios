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
    private var isApplyingRemote = false

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
                guard let self = self else { return }
                if let error = error {
                    self.status = .failed(error.localizedDescription)
                    return
                }
                guard let snapshot = snapshot else { return }
                self.applyReceiptChanges(snapshot.documentChanges, context: context)
            }
    }

    private func applyReceiptChanges(_ changes: [DocumentChange], context: NSManagedObjectContext) {
        guard !changes.isEmpty else {
            status = .synced(Date())
            return
        }

        isApplyingRemote = true
        defer {
            isApplyingRemote = false
            status = .synced(Date())
        }

        for change in changes {
            let document = change.document.data()
            guard let id = (document["id"] as? String).flatMap(UUID.init(uuidString:)) else { continue }

            let request = CDReceipt.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let existing = try? context.fetch(request).first

            switch change.type {
            case .removed:
                if let existing = existing { context.delete(existing) }
            case .added, .modified:
                // A local edit newer than the remote one wins and is pushed back.
                let remoteDate = ReceiptDocument.date(document["updatedAt"]) ?? .distantPast
                if let existing = existing, let localDate = existing.updatedAt, localDate > remoteDate {
                    Task { await push(receipt: existing) }
                    continue
                }
                let receipt = existing ?? CDReceipt(context: context)
                if existing == nil { receipt.id = id }
                ReceiptDocument.apply(document, to: receipt, in: context)
            }
        }

        saveQuietly(context)
    }

    private func listenForMembers(uid: String, context: NSManagedObjectContext) {
        memberListener = database.collection("users").document(uid).collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, error == nil, let snapshot = snapshot else { return }

                self.isApplyingRemote = true
                defer { self.isApplyingRemote = false }

                for change in snapshot.documentChanges {
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

                self.saveQuietly(context)
            }
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
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, !self.isApplyingRemote else { return }
            Task { await self.pushChanges(from: notification) }
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
                await delete(id: receipt.id, from: "receipts")
            } else if let member = object as? CDMember {
                await delete(id: member.id, from: "members")
            }
        }
    }

    @discardableResult
    func push(receipt: CDReceipt) async -> Bool {
        guard let uid = uid else { return false }

        // Stamp the edit so the other device can tell which copy is newer.
        if receipt.updatedAt == nil || !isApplyingRemote {
            receipt.updatedAt = Date()
        }
        let payload = ReceiptDocument.dictionary(from: receipt)
        let id = receipt.id.uuidString

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

        if member.updatedAt == nil || !isApplyingRemote {
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

    private func delete(id: UUID, from collection: String) async {
        guard let uid = uid else { return }
        try? await database.collection("users").document(uid)
            .collection(collection).document(id.uuidString).delete()
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
