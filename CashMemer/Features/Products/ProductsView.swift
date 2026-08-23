import CoreData
import SwiftUI

/// The shop catalogue.
///
/// Two entry points onto one table, matching how the Android build splits them.
/// **Products** is the barcode side: scan at the till, look the item up, track
/// stock. **Price List** is everything priced by hand, where a barcode would be
/// noise. `scope` decides which of the two this instance is.
struct ProductsView: View {
    enum Scope {
        /// Everything, barcoded or not — the stock-keeping view.
        case products
        /// Hand-priced only. Kept deliberately plain: a name and a price.
        case priceList

        var titleKey: L10n.Key { self == .products ? .products : .priceList }
    }

    let scope: Scope

    @Environment(\.managedObjectContext) private var context
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var settings: AppSettings

    @FetchRequest(fetchRequest: CDProduct.allRequest()) private var products: FetchedResults<CDProduct>

    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var editing: CDProduct?
    @State private var isCreating = false
    @State private var isScanning = false
    /// Set when a scan matches nothing: the editor opens with the code filled in.
    @State private var pendingBarcode: String?

    private enum Filter: CaseIterable {
        case all, active, archived
        var key: L10n.Key {
            switch self {
            case .all: return .filterAll
            case .active: return .filterActive
            case .archived: return .archived
            }
        }
    }

    private var visible: [CDProduct] {
        products.filter { product in
            // Price List is the no-barcode half; Products shows the whole shelf.
            if scope == .priceList && product.hasBarcode { return false }

            switch filter {
            case .all: break
            case .active: if product.isArchived { return false }
            case .archived: if !product.isArchived { return false }
            }

            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return true }
            return product.name.localizedCaseInsensitiveContains(trimmed)
                || product.category.localizedCaseInsensitiveContains(trimmed)
                || (product.barcode ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                addButton
                if scope == .products {
                    searchField
                    filterChips
                    summary
                }
                if visible.isEmpty {
                    emptyState
                } else {
                    ForEach(visible) { product in
                        row(product)
                    }
                }
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(L10n.string(scope.titleKey, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isCreating) {
            ProductEditorSheet(product: nil, presetBarcode: nil, scope: scope)
        }
        .sheet(item: $editing) { product in
            ProductEditorSheet(product: product, presetBarcode: nil, scope: scope)
        }
        .sheet(isPresented: $isScanning) {
            BarcodeScannerSheet { code in
                scanned(code)
            }
        }
        .sheet(isPresented: Binding(
            get: { pendingBarcode != nil },
            set: { if !$0 { pendingBarcode = nil } }
        )) {
            ProductEditorSheet(product: nil, presetBarcode: pendingBarcode, scope: scope)
        }
    }

    // MARK: - Pieces

    private var addButton: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                isCreating = true
            } label: {
                Label(L10n.string(.addNewProduct, language: language), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundColor(.white)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)

            // Scanning only makes sense on the barcode side.
            if scope == .products {
                Button {
                    isScanning = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title3)
                        .frame(width: 48, height: 46)
                        .foregroundColor(Theme.brandDeep)
                        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string(.scanBarcode, language: language))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)
            TextField(L10n.string(.searchProducts, language: language), text: $query)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 11)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private var filterChips: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(Filter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(L10n.string(option.key, language: language))
                        .font(.subheadline.weight(filter == option ? .semibold : .regular))
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, 9)
                        .foregroundColor(filter == option ? Theme.brandDeep : Theme.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .fill(filter == option ? Theme.brandSoft : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .stroke(Theme.separator, lineWidth: filter == option ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var summary: some View {
        let active = products.filter { !$0.isArchived }
        let lowStock = active.filter(\.isLowStock).count
        let sellValue = active.reduce(Decimal.zero) {
            $0 + ($1.price.decimalValue * Decimal($1.stock))
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(active.count) \(L10n.string(.filterActive, language: language)) · \(lowStock) \(L10n.string(.lowStock, language: language))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.brandDeep)
            Text("\(L10n.string(.sellValue, language: language)): \(CurrencyFormatter.string(sellValue, currency: settings.defaultCurrency))")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private func row(_ product: CDProduct) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(product.name.isEmpty ? "—" : product.name)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer(minLength: Theme.Spacing.s)
                Text(CurrencyFormatter.string(product.price.decimalValue, currency: settings.defaultCurrency))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Theme.brand)
            }

            if scope == .products {
                if let barcode = product.barcode, !barcode.isEmpty {
                    Text("\(L10n.string(.barcode, language: language)): \(barcode)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                if !product.category.isEmpty {
                    Text("\(L10n.string(.category, language: language)): \(product.category)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Text("\(L10n.string(.stock, language: language)): \(product.stock) \(product.unit)")
                    .font(.caption)
                    .foregroundColor(product.isLowStock ? Theme.warning : Theme.textSecondary)
            } else {
                Text(product.unit)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            HStack(spacing: Theme.Spacing.s) {
                if scope == .products {
                    Text(L10n.string(product.isArchived ? .archived : .filterActive, language: language))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 6)
                        .foregroundColor(product.isArchived ? Theme.textSecondary : Theme.brandDeep)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .stroke(Theme.separator, lineWidth: 1)
                        )

                    Spacer(minLength: 0)

                    iconButton(product.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down", Theme.textSecondary) {
                        product.isArchived.toggle()
                        product.updatedAt = Date()
                        save()
                    }
                    iconButton("doc.on.doc", Theme.textSecondary) { duplicate(product) }
                } else {
                    Spacer(minLength: 0)
                }

                iconButton("pencil", Theme.brand) { editing = product }
                iconButton("trash", Theme.destructive) {
                    context.delete(product)
                    save()
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.separator, lineWidth: 1)
        )
    }

    private func iconButton(_ symbol: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 34, height: 32)
                .foregroundColor(tint)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: scope == .products ? "shippingbox" : "list.bullet.rectangle",
            titleKey: .noProductsYet,
            messageKey: .noProductsHint
        )
        .padding(.top, Theme.Spacing.xl)
    }

    // MARK: - Behaviour

    /// A scan either opens the product it matches, or starts a new one with the
    /// code already filled in — never a dead end.
    private func scanned(_ code: String) {
        if let existing = CDProduct.first(barcode: code, in: context) {
            editing = existing
        } else {
            pendingBarcode = code
        }
    }

    private func duplicate(_ product: CDProduct) {
        let copy = CDProduct.make(in: context)
        copy.name = product.name
        copy.category = product.category
        copy.unit = product.unit
        copy.price = product.price
        copy.stock = product.stock
        copy.lowStockThreshold = product.lowStockThreshold
        copy.notes = product.notes
        // Barcodes identify one product; a copy cannot share it.
        copy.barcode = nil
        save()
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
