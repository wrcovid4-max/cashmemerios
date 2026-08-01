import CoreData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language

    @State private var search = ""
    @State private var showsArchived = false
    @State private var selected: CDReceipt?
    @State private var isShowingDetail = false

    var body: some View {
        Group {
            if showsArchived {
                ReceiptList(request: CDReceipt.archivedRequest(), onSelect: open, onAction: handle)
            } else {
                ReceiptList(request: CDReceipt.activeRequest(search: search), onSelect: open, onAction: handle)
            }
        }
        .background(Theme.background)
        .searchable(text: $search, prompt: L10n.string(.searchReceipts, language: language))
        .navigationTitle(L10n.string(showsArchived ? .archive : .history, language: language))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showsArchived.toggle()
                } label: {
                    Image(systemName: showsArchived ? "tray.full" : "archivebox")
                }
                .accessibilityLabel(L10n.string(.archive, language: language))
            }
        }
        .navigationDestination(isPresented: $isShowingDetail) {
            if let selected = selected {
                ReceiptDetailView(receipt: selected)
            }
        }
        // A Spotlight result or Siri shortcut can ask for one specific receipt.
        .onChange(of: navigation.pendingReceiptID) { id in
            guard let id = id else { return }
            openReceipt(id: id)
            navigation.pendingReceiptID = nil
        }
        .onAppear {
            if let id = navigation.pendingReceiptID {
                openReceipt(id: id)
                navigation.pendingReceiptID = nil
            }
        }
    }

    private func open(_ receipt: CDReceipt) {
        selected = receipt
        isShowingDetail = true
    }

    private func openReceipt(id: UUID) {
        let request = CDReceipt.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        if let match = try? context.fetch(request).first {
            open(match)
        }
    }

    private func handle(_ action: ReceiptAction, _ receipt: CDReceipt) {
        switch action {
        case .archive:
            receipt.isArchived.toggle()
        case .delete:
            context.delete(receipt)
        case .duplicate:
            duplicate(receipt)
        }
        try? context.save()
    }

    /// Copies a memo as a fresh draft — the common case of a repeat sale to the
    /// same customer, with a new number and today's date.
    private func duplicate(_ receipt: CDReceipt) {
        let copy = CDReceipt(context: context)
        copy.id = UUID()
        copy.number = CDReceipt.generateNumber()
        copy.createdAt = Date()
        copy.title = receipt.title
        copy.storeName = receipt.storeName
        copy.address = receipt.address
        copy.latitude = receipt.latitude
        copy.longitude = receipt.longitude
        copy.memberID = receipt.memberID
        copy.customerName = receipt.customerName
        copy.customerPhone = receipt.customerPhone
        copy.customerEmail = receipt.customerEmail
        copy.currencyCode = receipt.currencyCode
        copy.categoryRaw = receipt.categoryRaw
        copy.paymentMethodRaw = receipt.paymentMethodRaw
        copy.discountTypeRaw = receipt.discountTypeRaw
        copy.discountValue = receipt.discountValue
        copy.taxPercent = receipt.taxPercent
        copy.cashGiven = receipt.cashGiven
        copy.note = receipt.note
        copy.notesPageTwo = receipt.notesPageTwo
        copy.signaturePNG = receipt.signaturePNG
        copy.isArchived = false
        copy.issuedByName = receipt.issuedByName
        copy.issuedByEmail = receipt.issuedByEmail

        for item in receipt.orderedItems {
            let line = CDReceiptItem(context: context)
            line.id = UUID()
            line.name = item.name
            line.quantity = item.quantity
            line.unitPrice = item.unitPrice
            line.sortIndex = item.sortIndex
            line.receipt = copy
        }
    }
}

enum ReceiptAction {
    case archive, delete, duplicate
}

/// Wraps `@FetchRequest` so the caller can swap predicates by re-initialising.
private struct ReceiptList: View {
    @FetchRequest private var receipts: FetchedResults<CDReceipt>
    private let onSelect: (CDReceipt) -> Void
    private let onAction: (ReceiptAction, CDReceipt) -> Void

    @Environment(\.appLanguage) private var language

    init(
        request: NSFetchRequest<CDReceipt>,
        onSelect: @escaping (CDReceipt) -> Void,
        onAction: @escaping (ReceiptAction, CDReceipt) -> Void
    ) {
        _receipts = FetchRequest(fetchRequest: request, animation: .default)
        self.onSelect = onSelect
        self.onAction = onAction
    }

    var body: some View {
        if receipts.isEmpty {
            EmptyStateView(
                systemImage: "doc.text.magnifyingglass",
                titleKey: .noReceiptsYet,
                messageKey: .noReceiptsHint
            )
        } else {
            List {
                ForEach(receipts) { receipt in
                    Button { onSelect(receipt) } label: {
                        ReceiptRow(receipt: receipt)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.card)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onAction(.delete, receipt)
                        } label: {
                            Label(L10n.string(.delete, language: language), systemImage: "trash")
                        }
                        Button {
                            onAction(.archive, receipt)
                        } label: {
                            Label(
                                L10n.string(receipt.isArchived ? .unarchive : .archive, language: language),
                                systemImage: receipt.isArchived ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        .tint(Theme.brand)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            onAction(.duplicate, receipt)
                        } label: {
                            Label(L10n.string(.duplicate, language: language), systemImage: "doc.on.doc")
                        }
                        .tint(Theme.warning)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }
}

struct ReceiptRow: View {
    @ObservedObject var receipt: CDReceipt

    @Environment(\.appLanguage) private var language

    private var title: String {
        let store = receipt.storeName.isEmpty ? receipt.title : receipt.storeName
        return store.isEmpty ? "#\(receipt.number)" : store
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.brandSoft)
                    .frame(width: 38, height: 38)
                Image(systemName: receipt.category.systemImage)
                    .foregroundColor(Theme.brandDeep)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(receipt.number) · \(receipt.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(receipt.totals.grandTotal, currency: receipt.currency))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(Theme.textPrimary)
                Text(L10n.string(receipt.paymentMethod.key, language: language))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let titleKey: L10n.Key
    let messageKey: L10n.Key

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundColor(Theme.textTertiary)
            Text(L10n.string(titleKey, language: language))
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text(L10n.string(messageKey, language: language))
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
