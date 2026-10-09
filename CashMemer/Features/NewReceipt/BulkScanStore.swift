import Foundation
import CoreData

/// Scans a batch of receipt photos one after another. Each receipt has its own
/// `ReceiptDraft`, so it can be opened in the form, edited, and saved later.
@MainActor
final class BulkScanStore: ObservableObject {
    static let shared = BulkScanStore()

    enum Status: Equatable { case waiting, scanning, done, failed }

    struct Item: Identifiable {
        let id: Int
        let imageData: Data
        var status: Status = .waiting
        let draft = ReceiptDraft()
    }

    @Published private(set) var items: [Item] = []
    private var durations: [TimeInterval] = []
    private var worker: Task<Void, Never>?

    var finishedCount: Int {
        items.filter { $0.status == .done || $0.status == .failed }.count
    }

    var isAllDone: Bool { !items.isEmpty && finishedCount == items.count }

    /// Estimated seconds left, from the receipts already scanned.
    var etaSeconds: TimeInterval? {
        let remaining = items.filter { $0.status == .waiting || $0.status == .scanning }.count
        guard !durations.isEmpty, remaining > 0 else { return nil }
        return durations.reduce(0, +) / Double(durations.count) * Double(remaining)
    }

    /// Adds photos to the batch and starts scanning if nothing is running.
    func enqueue(_ images: [Data], settings: AppSettings) {
        guard !images.isEmpty else { return }
        let start = items.count
        items += images.enumerated().map { Item(id: start + $0.offset, imageData: $0.element) }
        if worker == nil {
            worker = Task { await runWorker(settings: settings) }
        }
    }

    private func runWorker(settings: AppSettings) async {
        while let index = items.firstIndex(where: { $0.status == .waiting }) {
            await scanItem(at: index, settings: settings)
        }
        worker = nil
    }

    private func scanItem(at index: Int, settings: AppSettings) async {
        let started = Date()
        items[index].status = .scanning
        let item = items[index]
        ScanActivityController.shared.start(source: "Bulk", currencySymbol: item.draft.currency.symbol)
        do {
            let scanner: ReceiptScanning = GeminiReceiptScanner.apiKey?.isEmpty == false
                ? GeminiReceiptScanner()
                : VisionReceiptScanner()
            let result = try await scanner.scan(imageData: item.imageData)
            item.draft.adoptIssuer(from: settings)
            item.draft.apply(result, settings: settings)
            items[index].status = .done
            ScanActivityController.shared.finish(
                storeName: result.storeName,
                itemsFound: result.lines.count,
                total: result.total
            )
        } catch {
            items[index].status = .failed
            ScanActivityController.shared.finish(storeName: nil, itemsFound: 0, total: nil, failed: true)
        }
        durations.append(Date().timeIntervalSince(started))
    }

    /// Clears the batch without saving anything.
    func clear() {
        items = []
        durations = []
    }

    /// Saves every receipt that scanned successfully, then clears the batch.
    func saveAll(in context: NSManagedObjectContext, settings: AppSettings) throws {
        for item in items where item.status == .done && !item.draft.lines.isEmpty {
            item.draft.number = CDReceipt.nextNumber(in: context)
            item.draft.adoptIssuer(from: settings)
            _ = try item.draft.persist(in: context)
        }
        if context.hasChanges {
            try context.save()
        }
        clear()
    }
}
