import SwiftUI

struct WatchHistoryView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.appLanguage) private var language

    private var receipts: [WatchPayload.Summary] { session.payload.recent() }

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    emptyState
                } else {
                    List(receipts) { receipt in
                        NavigationLink {
                            WatchReceiptDetail(receipt: receipt, symbol: session.payload.currencySymbol)
                        } label: {
                            row(receipt)
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle(L10n.string(.history, language: language))
        }
        .refreshable { session.requestRefresh() }
    }

    private func row(_ receipt: WatchPayload.Summary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: receipt.category.systemImage)
                    .font(.caption2)
                    .foregroundColor(Theme.brand)
                Text(receipt.store.isEmpty ? receipt.number : receipt.store)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
            }
            Text(amount(receipt.total))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(Theme.brand)
            Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(L10n.string(.openOnIPhoneToSync, language: language))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func amount(_ value: Double) -> String {
        "\(session.payload.currencySymbol) \(String(format: "%.2f", value))"
    }
}

struct WatchReceiptDetail: View {
    let receipt: WatchPayload.Summary
    let symbol: String

    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(symbol) \(String(format: "%.2f", receipt.total))")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(Theme.brand)

                detail(.receiptNo, receipt.number)
                detail(.category, L10n.string(receipt.category.key, language: language))
                detail(.method, L10n.string(receipt.paymentMethod.key, language: language))
                detail(.date, receipt.date.formatted(date: .abbreviated, time: .shortened))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .navigationTitle(receipt.store.isEmpty ? receipt.number : receipt.store)
    }

    private func detail(_ key: L10n.Key, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(L10n.string(key, language: language))
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.footnote.weight(.medium))
        }
    }
}
