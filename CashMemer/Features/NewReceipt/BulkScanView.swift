import PhotosUI
import SwiftUI

/// Bulk scan: pick up to 10 receipt photos, watch the progress, open any receipt to
/// edit it, then save the whole batch or clear it.
struct BulkScanView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = BulkScanStore.shared

    @State private var selections: [PhotosPickerItem] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                pickCard
                if store.waitingForNetwork {
                    Text(L10n.string(.bulkWaitingNetwork, language: language))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                if !store.items.isEmpty {
                    progressCard
                    receiptsList
                }
                if store.isAllDone {
                    actionButtons
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.bulkTitle, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selections) { newSelections in
            Task { @MainActor in
                var images: [Data] = []
                for item in newSelections {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        images.append(data)
                    }
                }
                selections = []
                AppSounds.shared.play(.chime)
                store.enqueue(images, settings: settings)
            }
        }
        .alert(L10n.string(.bulkTitle, language: language), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.string(.gotIt, language: language), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var pickCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Text(L10n.string(.bulkHint, language: language))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                InfoButton(
                    title: L10n.string(.bulkTitle, language: language),
                    message: L10n.string(.infoBulk, language: language)
                )
            }
            Text(L10n.string(.bulkNetworkNote, language: language))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            PhotosPicker(selection: $selections, maxSelectionCount: 10, matching: .images) {
                Label(L10n.string(.bulkPick, language: language), systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(String(format: L10n.string(.bulkProgress, language: language),
                            store.finishedCount, store.items.count))
                    .font(.headline)
                Spacer()
                Text(etaLabel)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressView(value: Double(store.finishedCount), total: Double(store.items.count))
                .tint(.green)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var etaLabel: String {
        if store.isAllDone { return L10n.string(.bulkAllDone, language: language) }
        guard let seconds = store.etaSeconds else {
            return L10n.string(.bulkEtaCalculating, language: language)
        }
        if seconds >= 60 {
            return String(format: L10n.string(.bulkEtaMinutes, language: language), Int(seconds / 60) + 1)
        }
        return String(format: L10n.string(.bulkEtaSeconds, language: language), max(1, Int(seconds)))
    }

    private var receiptsList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(store.items) { item in
                receiptRow(item)
            }
        }
    }

    @ViewBuilder
    private func receiptRow(_ item: BulkScanStore.Item) -> some View {
        let label = String(format: L10n.string(.bulkReceiptNumber, language: language), item.id + 1)
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.body)
                Text(statusText(item.status))
                    .font(.caption)
                    .foregroundStyle(item.status == .failed ? Color.red : Theme.textSecondary)
                rowBar(item.status)
            }
            Spacer()
            if item.status == .done || item.status == .failed {
                NavigationLink {
                    NewReceiptView(draft: item.draft, isBulkItem: true)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.brand)
                        .accessibilityLabel(L10n.string(.bulkEdit, language: language))
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    /// Each receipt's own bar: animated while scanning, full when done, red when it failed.
    @ViewBuilder
    private func rowBar(_ status: BulkScanStore.Status) -> some View {
        switch status {
        case .scanning:
            ProgressView().progressViewStyle(.linear).tint(.green)
        case .done:
            ProgressView(value: 1).tint(.green)
        case .failed:
            ProgressView(value: 1).tint(.red)
        case .waiting:
            ProgressView(value: 0).tint(.green)
        }
    }

    private func statusIcon(_ status: BulkScanStore.Status) -> String {
        switch status {
        case .waiting: return "clock"
        case .scanning: return "hourglass"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func statusText(_ status: BulkScanStore.Status) -> String {
        switch status {
        case .waiting: return L10n.string(.bulkWaiting, language: language)
        case .scanning: return L10n.string(.bulkScanning, language: language)
        case .done: return L10n.string(.bulkDone, language: language)
        case .failed: return L10n.string(.bulkFailed, language: language)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(L10n.string(.bulkClear, language: language), role: .destructive) {
                store.clear()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button(L10n.string(.bulkSave, language: language)) {
                do {
                    try store.saveAll(in: context, settings: settings)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .frame(maxWidth: .infinity)
        }
    }
}
