import Charts
import CoreData
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var period: DashboardPeriod = .month
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var isShowingCustomRange = false

    private var range: Range<Date> {
        if period == .custom {
            let end = max(customEnd, customStart)
            return customStart..<(Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end)
        }
        return period.range() ?? Date()..<Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                periodPicker
                MetricsSection(range: range, currency: settings.defaultCurrency)
                chartsRow
                RatesCard(compact: true)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(.dashboard, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingCustomRange) { customRangeSheet }
    }

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(DashboardPeriod.allCases) { option in
                    Button {
                        period = option
                        if option == .custom { isShowingCustomRange = true }
                    } label: {
                        HStack(spacing: 5) {
                            if option == .custom {
                                Image(systemName: "calendar").font(.caption)
                            }
                            Text(L10n.string(option.key, language: language))
                                .font(.subheadline.weight(period == option ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(period == option ? .white : Theme.textPrimary)
                        .background(period == option ? Theme.brand : Theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    /// Side by side on iPad, stacked on iPhone.
    @ViewBuilder
    private var chartsRow: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                RevenueTrendCard(range: range, period: period, currency: settings.defaultCurrency)
                InsightsCard(range: range, currency: settings.defaultCurrency)
                    .frame(maxWidth: 380)
            }
        } else {
            RevenueTrendCard(range: range, period: period, currency: settings.defaultCurrency)
            InsightsCard(range: range, currency: settings.defaultCurrency)
        }
    }

    private var customRangeSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    L10n.string(.date, language: language),
                    selection: $customStart,
                    displayedComponents: .date
                )
                DatePicker(
                    L10n.string(.periodCustom, language: language),
                    selection: $customEnd,
                    in: customStart...,
                    displayedComponents: .date
                )
            }
            .navigationTitle(L10n.string(.periodCustom, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.done, language: language)) { isShowingCustomRange = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Metrics

private struct MetricsSection: View {
    @FetchRequest private var receipts: FetchedResults<CDReceipt>
    private let currency: Currency

    @Environment(\.appLanguage) private var language

    init(range: Range<Date>, currency: Currency) {
        _receipts = FetchRequest(fetchRequest: CDReceipt.request(in: range), animation: .default)
        self.currency = currency
    }

    private var metrics: DashboardMetrics {
        DashboardMetrics(receipts: Array(receipts))
    }

    var body: some View {
        let metrics = self.metrics
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.m)],
            spacing: Theme.Spacing.m
        ) {
            StatTile(
                icon: "doc.text.fill",
                accent: Theme.statAccents[0],
                value: "\(metrics.count)",
                caption: L10n.string(.invoices, language: language)
            )
            StatTile(
                icon: "storefront.fill",
                accent: Theme.statAccents[1],
                value: metrics.topStore ?? "–",
                caption: L10n.string(.topStore, language: language),
                valueFont: .headline
            )
            StatTile(
                icon: "calendar",
                accent: Theme.statAccents[2],
                value: CurrencyFormatter.compact(metrics.total, currency: currency),
                caption: L10n.string(.thisMonth, language: language)
            )
            StatTile(
                icon: "creditcard.fill",
                accent: Theme.statAccents[3],
                value: CurrencyFormatter.compact(metrics.average, currency: currency),
                caption: L10n.string(.avgReceipt, language: language)
            )
            StatTile(
                icon: "cart.fill",
                accent: Theme.statAccents[4],
                value: "\(metrics.itemCount)",
                caption: L10n.string(.totalItems, language: language)
            )
            StatTile(
                icon: "tag.fill",
                accent: Theme.statAccents[5],
                value: metrics.topCategory.map { L10n.string($0.key, language: language) } ?? "–",
                caption: L10n.string(.topCategory, language: language),
                valueFont: .headline
            )
        }
    }
}

// MARK: - Revenue trend

private struct RevenueTrendCard: View {
    @FetchRequest private var receipts: FetchedResults<CDReceipt>
    private let period: DashboardPeriod
    private let currency: Currency

    @Environment(\.appLanguage) private var language
    @State private var isBarChart = false

    init(range: Range<Date>, period: DashboardPeriod, currency: Currency) {
        _receipts = FetchRequest(fetchRequest: CDReceipt.request(in: range), animation: .default)
        self.period = period
        self.currency = currency
    }

    private var buckets: [RevenueBucket] {
        DashboardMetrics.buckets(for: Array(receipts), component: period.chartComponent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Label(
                    L10n.string(.revenueTrend, language: language),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

                Spacer()

                Picker("", selection: $isBarChart) {
                    Image(systemName: "chart.xyaxis.line").tag(false)
                    Image(systemName: "chart.bar.fill").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 96)
            }

            if buckets.isEmpty {
                Text(L10n.string(.noDataForPeriod, language: language))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                chart.frame(height: 220)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private var chart: some View {
        Chart(buckets) { bucket in
            if isBarChart {
                BarMark(
                    x: .value("Date", bucket.date, unit: period.chartComponent),
                    y: .value("Revenue", bucket.doubleTotal)
                )
                .foregroundStyle(Theme.brand)
                .cornerRadius(4)
            } else {
                AreaMark(
                    x: .value("Date", bucket.date, unit: period.chartComponent),
                    y: .value("Revenue", bucket.doubleTotal)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.brand.opacity(0.28), Theme.brand.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", bucket.date, unit: period.chartComponent),
                    y: .value("Revenue", bucket.doubleTotal)
                )
                .foregroundStyle(Theme.brand)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Theme.separator)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(CurrencyFormatter.compact(Decimal(amount), currency: currency))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.separator.opacity(0.5))
                AxisValueLabel().font(.caption2)
            }
        }
    }
}

// MARK: - Insights

private struct InsightsCard: View {
    @FetchRequest private var receipts: FetchedResults<CDReceipt>
    private let currency: Currency

    @Environment(\.appLanguage) private var language

    init(range: Range<Date>, currency: Currency) {
        _receipts = FetchRequest(fetchRequest: CDReceipt.request(in: range), animation: .default)
        self.currency = currency
    }

    var body: some View {
        let insights = DashboardMetrics(receipts: Array(receipts)).insights(currency: currency)
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(L10n.string(.insights, language: language), systemImage: "sparkles")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            if insights.isEmpty {
                Text(L10n.string(.notEnoughData, language: language))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: Theme.Spacing.s) {
                            Circle()
                                .fill(Theme.brand)
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                            Text(insight)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
