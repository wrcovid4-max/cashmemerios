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
    @Environment(\.locale) private var locale

    @State private var query = ""

    /// The compact card on the Dashboard keeps the short curated list; the Rates
    /// tab lists everything the API actually returned.
    ///
    /// Reading the codes off the response rather than a hardcoded table means the
    /// list is always exactly what this key supports — it cannot drift, and a
    /// currency the API adds or drops needs no change here.
    private var codes: [String] {
        let curated = settings.availableCurrencies
            .map(\.code)
            .filter { $0 != settings.defaultCurrencyCode }

        guard !compact, let snapshot = stats.rates, !snapshot.rates.isEmpty else {
            return curated
        }

        var all = Set(snapshot.ratesIncludingToman.keys)
        all.remove(settings.defaultCurrencyCode)

        let sorted = all.sorted()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
                || name(for: $0).localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            baseRow
            if !compact { searchField }
            grid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)
            TextField(L10n.string(.searchCurrencies, language: language), text: $query)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 9)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
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
                    if !compact {
                        Text(name(for: code))
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
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
        guard let rate = rate(for: code) else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: rate as NSDecimalNumber) ?? "—"
    }

    private func rate(for code: String) -> Decimal? {
        stats.rates?.ratesIncludingToman[code]
    }

    /// Foundation already knows every ISO currency name in every language it
    /// ships, so there is no table to write or translate here.
    private func name(for code: String) -> String {
        if code == ExchangeRateService.Snapshot.tomanCode {
            return L10n.string(.iranianToman, language: language)
        }
        return locale.localizedString(forCurrencyCode: code) ?? code
    }
}
