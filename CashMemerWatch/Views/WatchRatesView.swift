import SwiftUI

/// The third watch page: every quote the phone last sent.
///
/// The watch holds no API key and makes no network call of its own — the rates
/// ride along in the `WatchPayload`, so this page works out of range of the
/// phone from the cached copy, exactly like History.
struct WatchRatesView: View {
    @EnvironmentObject private var session: WatchSessionService
    @Environment(\.appLanguage) private var language
    @Environment(\.locale) private var locale

    private var rates: [WatchPayload.Rate] { session.payload.sortedRates }

    var body: some View {
        NavigationStack {
            Group {
                if rates.isEmpty {
                    emptyState
                } else {
                    List {
                        baseRow
                        ForEach(rates) { rate in
                            row(rate)
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle(L10n.string(.rates, language: language))
        }
        .refreshable { session.requestRefresh() }
    }

    /// Which currency everything below is quoted against — without it the
    /// numbers are meaningless.
    private var baseRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10))
            Text(session.payload.base)
                .font(.system(.footnote, design: .rounded).weight(.bold))
            Spacer()
            Text(session.payload.generatedAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .foregroundColor(Theme.brand)
    }

    private func row(_ rate: WatchPayload.Rate) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(rate.code)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                Spacer(minLength: 4)
                Text(value(rate.value))
                    .font(.system(size: 12, design: .rounded).monospacedDigit())
                    .foregroundColor(Theme.brand)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(name(for: rate.code))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
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

    /// Four decimals like the phone, but small rates would round to 0.0000, so
    /// those get more — a rial quote is worthless at four.
    private func value(_ amount: Double) -> String {
        let digits = abs(amount) < 0.01 ? 6 : 4
        return String(format: "%.\(digits)f", amount)
    }

    private func name(for code: String) -> String {
        if code == "TMN" { return L10n.string(.iranianToman, language: language) }
        return locale.localizedString(forCurrencyCode: code) ?? code
    }
}
