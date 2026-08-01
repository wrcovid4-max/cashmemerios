import CoreData
import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget showing today's receipt count and revenue.
struct TodaySummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySummaryWidget", provider: TodayProvider()) { entry in
            TodaySummaryView(entry: entry)
        }
        .configurationDisplayName("Today's Receipts")
        .description("Receipts and revenue recorded today.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline, .accessoryCircular
        ])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let count: Int
    let total: Decimal
    let currency: Currency
    let topStore: String?

    static let placeholder = TodayEntry(
        date: Date(), count: 4, total: 12_450, currency: .pkr, topStore: "Chapters"
    )
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes, and again at midnight when "today" rolls over.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        let next = min(Date().addingTimeInterval(1_800), midnight)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> TodayEntry {
        let settings = AppSettings()
        let context = PersistenceController.shared.container.viewContext

        guard let range = DashboardPeriod.today.range(),
              let receipts = try? context.fetch(CDReceipt.request(in: range)) else {
            return TodayEntry(date: Date(), count: 0, total: 0, currency: settings.defaultCurrency, topStore: nil)
        }

        let metrics = DashboardMetrics(receipts: receipts)
        return TodayEntry(
            date: Date(),
            count: metrics.count,
            total: metrics.total,
            currency: settings.defaultCurrency,
            topStore: metrics.topStore
        )
    }
}

struct TodaySummaryView: View {
    let entry: TodayEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.count) · \(CurrencyFormatter.compact(entry.total, currency: entry.currency))")
        case .accessoryCircular:
            Gauge(value: Double(min(entry.count, 20)), in: 0...20) {
                Image(systemName: "doc.text")
            } currentValueLabel: {
                Text("\(entry.count)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.headline)
                Text(CurrencyFormatter.string(entry.total, currency: entry.currency))
                    .font(.body)
                Text("\(entry.count) receipts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        default:
            homeScreen
        }
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Theme.brand)
                Text("Cash Memer")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Text(CurrencyFormatter.compact(entry.total, currency: entry.currency))
                .font(.system(.title, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(entry.count) receipts today")
                .font(.caption)
                .foregroundColor(.secondary)

            if family == .systemMedium, let topStore = entry.topStore {
                Spacer(minLength: 0)
                Label(topStore, systemImage: "storefront")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .widgetURL(URL(string: "cashmemer://dashboard"))
    }
}
