import FirebaseFirestore
import Foundation

/// Finds where the other apps actually keep their data.
///
/// The Firestore client SDK cannot list subcollections — only the Admin SDK can —
/// so there is no way to ask "what is under `users/{uid}`?" from the app. What it
/// *can* do is read a named collection and see whether anything comes back. This
/// tries the plausible names once at startup and logs the ones that are not empty,
/// along with the first document's id and field names.
///
/// iOS listens on `users/{uid}/receipts` and `users/{uid}/members` because that is
/// what I guessed when writing the sync. If the Android and older iOS apps used
/// different names, nothing arrives and sync still reports success — which is
/// exactly the symptom. This says so in one line instead of another round of
/// guessing.
///
/// Diagnostic only: it reads at most three documents per name and writes nothing.
enum SyncDiagnostics {
    /// Names worth trying, in rough order of likelihood.
    private static let candidates = [
        "receipts", "receipt", "memos", "memo", "cashMemos", "cashmemos", "cash_memos",
        "invoices", "bills", "records", "history", "transactions", "entries",
        "members", "member", "customers", "clients", "contacts", "people",
        "backups", "data", "items"
    ]

    static func probe(uid: String, database: Firestore) async {
        NSLog("CashMemer probe: signed in as uid %@", uid)

        var found: [String] = []
        let root = database.collection("users").document(uid)

        for name in candidates {
            do {
                let snapshot = try await root.collection(name).limit(to: 3).getDocuments()
                guard !snapshot.isEmpty else { continue }

                found.append("\(name)(\(snapshot.count)+)")
                let first = snapshot.documents[0]
                let fields = Array(first.data().keys).sorted().joined(separator: ",")
                NSLog(
                    "CashMemer probe: users/<uid>/%@ has documents. first id=%@ fields=[%@]",
                    name, first.documentID, fields
                )
            } catch {
                // Permission denied is itself informative: the collection exists in
                // the rules but is not readable, which is a different problem.
                NSLog("CashMemer probe: users/<uid>/%@ → %@", name, error.localizedDescription)
            }
        }

        if found.isEmpty {
            NSLog("CashMemer probe: nothing found under users/<uid>. The other apps store their data somewhere else entirely.")
        } else {
            NSLog("CashMemer probe: non-empty collections → %@", found.joined(separator: " "))
        }
    }
}
