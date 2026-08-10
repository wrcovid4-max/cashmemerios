import CarPlay
import CoreData
import UIKit

/// CarPlay: History, Rates and Dashboard. Read-only by design — CarPlay templates
/// exist to keep eyes on the road, and creating a memo needs a keyboard and a
/// signature anyway.
///
/// **This runs in the simulator.** On a real head unit it also needs the
/// `com.apple.developer.carplay-driving-task` entitlement, which Apple grants by
/// application only. The simulator does not validate entitlements against a
/// provisioning profile, so the entitlement lives in a simulator-only file
/// (`CashMemer-Simulator.entitlements`, wired up per-SDK in `project.yml`) and
/// device builds keep signing with the free personal team.
///
/// To test: run on any iPhone simulator, then **I/O → External Displays →
/// CarPlay** in the Simulator menu bar.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    private var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let settings = AppSettings()
        let language = settings.language

        let tabs = CPTabBarTemplate(templates: [
            historyTemplate(settings: settings, language: language),
            ratesTemplate(settings: settings, language: language),
            dashboardTemplate(settings: settings, language: language)
        ])

        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    // MARK: - History

    private func historyTemplate(settings: AppSettings, language: AppLanguage) -> CPListTemplate {
        let request = CDReceipt.activeRequest()
        // CarPlay caps how many rows a template may carry, and the cap is a hard
        // limit rather than a truncation — going over throws.
        request.fetchLimit = min(CPListTemplate.maximumItemCount, 40)
        let receipts = (try? context.fetch(request)) ?? []

        let items: [CPListItem] = receipts.map { receipt in
            let store = receipt.storeName.isEmpty ? receipt.title : receipt.storeName
            let total = CurrencyFormatter.string(receipt.totals.grandTotal, currency: receipt.currency)
            let date = receipt.createdAt.formatted(date: .abbreviated, time: .shortened)
            return CPListItem(
                text: store.isEmpty ? receipt.number : store,
                detailText: "\(total) · \(date)"
            )
        }

        let template = CPListTemplate(
            title: L10n.string(.history, language: language),
            sections: [CPListSection(items: items)]
        )
        template.tabTitle = L10n.string(.history, language: language)
        template.tabImage = UIImage(systemName: "list.bullet.rectangle.portrait.fill")
        template.emptyViewSubtitleVariants = [L10n.string(.noReceiptsHint, language: language)]
        return template
    }

    // MARK: - Rates

    private func ratesTemplate(settings: AppSettings, language: AppLanguage) -> CPListTemplate {
        let template = CPListTemplate(
            title: L10n.string(.rates, language: language),
            sections: []
        )
        template.tabTitle = L10n.string(.rates, language: language)
        template.tabImage = UIImage(systemName: "dollarsign.circle.fill")
        template.emptyViewSubtitleVariants = [L10n.string(.openOnIPhoneToSync, language: language)]

        // The cached snapshot is read off disk, so CarPlay shows the last known
        // rates without waiting on — or requiring — a network round trip.
        Task { [weak template] in
            guard let snapshot = await ExchangeRateService().lastSnapshot else { return }
            let quotes = snapshot.ratesIncludingToman
                .sorted { $0.key < $1.key }
                .prefix(CPListTemplate.maximumItemCount)

            let items: [CPListItem] = quotes.map { code, rate in
                CPListItem(
                    text: code,
                    detailText: Self.rateText(rate) + "  ·  1 \(snapshot.base)"
                )
            }
            await MainActor.run {
                template?.updateSections([CPListSection(items: items)])
            }
        }

        return template
    }

    private static func rateText(_ rate: Decimal) -> String {
        // A rial quote rounds to 0.0000 at four places, so tiny rates get more.
        let digits = abs(NSDecimalNumber(decimal: rate).doubleValue) < 0.01 ? 6 : 4
        return String(format: "%.\(digits)f", NSDecimalNumber(decimal: rate).doubleValue)
    }

    // MARK: - Dashboard

    private func dashboardTemplate(settings: AppSettings, language: AppLanguage) -> CPInformationTemplate {
        let currency = settings.defaultCurrency
        var items: [CPInformationItem] = []

        if let today = DashboardPeriod.today.range() {
            let receipts = (try? context.fetch(CDReceipt.request(in: today))) ?? []
            let total = receipts.reduce(Decimal.zero) { $0 + $1.totals.grandTotal }
            items.append(CPInformationItem(
                title: L10n.string(.todaysRevenue, language: language),
                detail: CurrencyFormatter.string(total, currency: currency)
            ))
            items.append(CPInformationItem(
                title: L10n.string(.todaysSales, language: language),
                detail: "\(receipts.count)"
            ))
        }

        if let month = DashboardPeriod.month.range() {
            let receipts = (try? context.fetch(CDReceipt.request(in: month))) ?? []
            let total = receipts.reduce(Decimal.zero) { $0 + $1.totals.grandTotal }
            items.append(CPInformationItem(
                title: L10n.string(.thisMonth, language: language),
                detail: CurrencyFormatter.string(total, currency: currency)
            ))
            let average = receipts.isEmpty ? Decimal.zero : total / Decimal(receipts.count)
            items.append(CPInformationItem(
                title: L10n.string(.avgReceipt, language: language),
                detail: CurrencyFormatter.string(average, currency: currency)
            ))
        }

        let template = CPInformationTemplate(
            title: L10n.string(.dashboard, language: language),
            layout: .leading,
            items: items,
            actions: []
        )
        template.tabTitle = L10n.string(.dashboard, language: language)
        template.tabImage = UIImage(systemName: "chart.bar.fill")
        return template
    }
}
