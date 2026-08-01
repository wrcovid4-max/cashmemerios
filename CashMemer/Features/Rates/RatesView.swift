import SwiftUI

struct RatesView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                RatesCard(compact: false)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.rates, language: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Live Exchange Rates" — base currency, refresh control and a grid of quotes.
struct RatesCard: View {
    var compact: Bool

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: QuickStatsService
    @Environment(\.appLanguage) private var language

    private var codes: [String] {
        settings.availableCurrencies
            .map(\.code)
            .filter { $0 != settings.defaultCurrencyCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            baseRow
            grid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var header: some View {
        HStack {
            Label(
                L10n.string(.liveExchangeRates, language: language),
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.headline)
            .foregroundColor(Theme.textPrimary)

            Spacer()

            Button {
                Task { await stats.refresh(base: settings.defaultCurrencyCode) }
            } label: {
                if stats.isRefreshing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.brand)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.refresh, language: language))
        }
    }

    private var baseRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(settings.defaultCurrencyCode)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Theme.brand)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundColor(Theme.brand)
            }
            if let updatedAt = stats.updatedAtText {
                Text("\(L10n.string(.updatedAt, language: language)) \(updatedAt)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            } else if let error = stats.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Theme.destructive)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: compact ? 110 : 140), spacing: Theme.Spacing.s)],
            spacing: Theme.Spacing.s
        ) {
            ForEach(codes, id: \.self) { code in
                VStack(alignment: .leading, spacing: 2) {
                    Text(code)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(rateText(for: code))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
        }
    }

    /// Units of `code` per one unit of the base currency, as the API reports it.
    private func rateText(for code: String) -> String {
        guard let rate = stats.rates?.rates[code] else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: rate as NSDecimalNumber) ?? "—"
    }
}
