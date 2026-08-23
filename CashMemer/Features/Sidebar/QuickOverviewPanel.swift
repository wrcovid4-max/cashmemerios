import CoreData
import SwiftUI

/// FX chips plus the six at-a-glance tiles docked under the sidebar destinations.
struct QuickOverviewPanel: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: QuickStatsService
    @FetchRequest(fetchRequest: CDReceipt.activeRequest()) private var receipts: FetchedResults<CDReceipt>

    private var todaysReceipts: [CDReceipt] {
        receipts.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var todaysRevenue: Decimal {
        todaysReceipts.reduce(Decimal.zero) { $0 + $1.totals.grandTotal }
    }

    /// Distinct item names ever sold — the "Total Products" tile.
    private var totalProducts: Int {
        Set(receipts.flatMap { $0.orderedItems.map(\.name) }.filter { !$0.isEmpty }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(L10n.string(.quickOverview, language: settings.language))
                .sectionCaption()

            currencyChips

            if let updatedAt = stats.updatedAtText {
                Text("\(L10n.string(.ratesAt, language: settings.language)): \(updatedAt)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            tiles
        }
        .padding(.bottom, Theme.Spacing.l)
    }

    /// Two columns, matching the tiles below.
    ///
    /// This was a horizontal ScrollView, which the sidebar is too narrow for: four
    /// chips do not fit, so the last one was sliced down the middle at the edge and
    /// read as a rendering bug rather than as something scrollable.
    private var currencyChips: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)],
            spacing: Theme.Spacing.s
        ) {
            ForEach(chipCodes, id: \.self) { code in
                CurrencyChip(
                    code: code,
                    baseCode: settings.defaultCurrencyCode,
                    value: stats.inverseRate(for: code)
                )
            }
        }
    }

    /// Never quote the base against itself — "USD → USD" is noise.
    private var chipCodes: [String] {
        QuickStatsService.chipCodes.filter { $0 != settings.defaultCurrencyCode }
    }

    private var tiles: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)],
            spacing: Theme.Spacing.s
        ) {
            StatTile(
                icon: "cart",
                accent: Theme.brand,
                value: "\(todaysReceipts.count)",
                caption: L10n.string(.todaysSales, language: settings.language)
            )
            StatTile(
                icon: "banknote",
                accent: Theme.brand,
                value: CurrencyFormatter.compact(todaysRevenue, currency: settings.defaultCurrency),
                caption: L10n.string(.todaysRevenue, language: settings.language)
            )
            StatTile(
                icon: "shippingbox",
                accent: Theme.brand,
                value: "\(totalProducts)",
                caption: L10n.string(.totalProducts, language: settings.language)
            )
            StatTile(
                icon: "viewfinder",
                accent: Theme.brand,
                value: "\(settings.scansToday)",
                caption: L10n.string(.scansToday, language: settings.language)
            )
            StatTile(
                icon: stats.isRateAPIOnline ? "cloud.fill" : "cloud.slash",
                accent: stats.isRateAPIOnline ? Theme.brand : Theme.textSecondary,
                value: L10n.string(stats.isRateAPIOnline ? .online : .offline, language: settings.language),
                caption: L10n.string(.rateAPI, language: settings.language),
                valueFont: .subheadline.weight(.semibold)
            )
            StatTile(
                icon: stats.weather?.symbolName ?? "sun.max",
                accent: Theme.warning,
                value: stats.weather?.temperatureText ?? "—",
                caption: L10n.string(.weather, language: settings.language)
            )
        }
    }
}

/// `USD → PKR` over `277.90`.
private struct CurrencyChip: View {
    let code: String
    let baseCode: String
    let value: Decimal?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(code)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                Text(baseCode)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(value.map { formatted($0) } ?? "—")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 78, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private func formatted(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}

/// Icon, big value, caption — the tile shape used in the sidebar and on the Dashboard.
struct StatTile: View {
    let icon: String
    let accent: Color
    let value: String
    let caption: String
    var valueFont: Font = .title3.weight(.bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(accent)
            Text(value)
                .font(valueFont)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}
