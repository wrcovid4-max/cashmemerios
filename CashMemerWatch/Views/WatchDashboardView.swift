import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.appLanguage) private var language

    private var symbol: String { session.payload.currencySymbol }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    todayCard
                    HStack(spacing: 8) {
                        metric(
                            value: "\(session.payload.todaysTotals().count)",
                            caption: L10n.string(.todaysSales, language: language)
                        )
                        metric(
                            value: compact(session.payload.weekTotal),
                            caption: L10n.string(.periodWeek, language: language)
                        )
                    }
                    if let top = topCategory {
                        metric(
                            value: L10n.string(top.key, language: language),
                            caption: L10n.string(.topCategory, language: language)
                        )
                    }
                    if session.payload.receipts.isEmpty {
                        Text(L10n.string(.openOnIPhoneToSync, language: language))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle(L10n.string(.dashboard, language: language))
        }
        .refreshable { session.requestRefresh() }
    }

    private var todayCard: some View {
        VStack(spacing: 2) {
            Text(L10n.string(.todaysRevenue, language: language))
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(symbol) \(String(format: "%.0f", session.payload.todaysTotals().total))")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(Theme.brand)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.brand.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metric(value: String, caption: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(caption)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var topCategory: ReceiptCategory? {
        var counts: [ReceiptCategory: Int] = [:]
        for receipt in session.payload.receipts { counts[receipt.category, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }

    private func compact(_ value: Double) -> String {
        if value >= 1000 { return "\(symbol) \(String(format: "%.1fK", value / 1000))" }
        return "\(symbol) \(String(format: "%.0f", value))"
    }
}
