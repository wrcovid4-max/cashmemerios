import CoreData
import SwiftUI

/// Add or edit one catalogue entry.
///
/// The same sheet serves both pages; `scope` only decides how much of it is
/// shown. The Price List has no use for barcodes, stock or low-stock warnings,
/// and hiding them keeps that page as quick to fill in as writing on a pad.
struct ProductEditorSheet: View {
    let product: CDProduct?
    let presetBarcode: String?
    let scope: ProductsView.Scope

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var settings: AppSettings

    @State private var name = ""
    @State private var barcode = ""
    @State private var category = ""
    @State private var unit = "piece"
    @State private var priceText = ""
    @State private var stockText = "0"
    @State private var lowStockText = "0"
    @State private var notes = ""
    @State private var isScanning = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.string(.itemName, language: language), text: $name)
                    TextField(L10n.string(.price, language: language), text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField(L10n.string(.unit, language: language), text: $unit)
                }

                if scope == .products {
                    Section(L10n.string(.barcode, language: language)) {
                        HStack {
                            TextField(L10n.string(.barcode, language: language), text: $barcode)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                            Button {
                                isScanning = true
                            } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundColor(Theme.brand)
                            }
                            .buttonStyle(.plain)
                        }
                        if let clash = duplicateBarcodeOwner {
                            Text("\(L10n.string(.barcodeInUse, language: language)) — \(clash)")
                                .font(.caption)
                                .foregroundColor(Theme.destructive)
                        }
                    }

                    Section(L10n.string(.stock, language: language)) {
                        TextField(L10n.string(.category, language: language), text: $category)
                        TextField(L10n.string(.stock, language: language), text: $stockText)
                            .keyboardType(.numberPad)
                        TextField(L10n.string(.lowStock, language: language), text: $lowStockText)
                            .keyboardType(.numberPad)
                    }
                }

                Section(L10n.string(.notes, language: language)) {
                    TextField(L10n.string(.notes, language: language), text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(L10n.string(product == nil ? .addNewProduct : .editProduct, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.save, language: language), action: save)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isScanning) {
                BarcodeScannerSheet { barcode = $0 }
            }
            .onAppear(perform: load)
        }
    }

    /// Warns rather than blocks: the same code on two products is nearly always a
    /// mistake, but only the shopkeeper knows for certain.
    private var duplicateBarcodeOwner: String? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let owner = CDProduct.first(barcode: trimmed, in: context),
              owner.id != product?.id
        else { return nil }
        return owner.name
    }

    private func load() {
        guard let product = product else {
            barcode = presetBarcode ?? ""
            return
        }
        name = product.name
        barcode = product.barcode ?? ""
        category = product.category
        unit = product.unit
        priceText = product.price == .zero ? "" : product.price.stringValue
        stockText = String(product.stock)
        lowStockText = String(product.lowStockThreshold)
        notes = product.notes
    }

    private func save() {
        let target = product ?? CDProduct.make(in: context)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.category = category.trimmingCharacters(in: .whitespaces)
        target.unit = unit.trimmingCharacters(in: .whitespaces).isEmpty
            ? "piece"
            : unit.trimmingCharacters(in: .whitespaces)
        target.notes = notes

        let parsedPrice = NSDecimalNumber(string: priceText.isEmpty ? "0" : priceText)
        target.price = parsedPrice == NSDecimalNumber.notANumber ? .zero : parsedPrice
        target.stock = Int32(stockText) ?? 0
        target.lowStockThreshold = Int32(lowStockText) ?? 0

        // Empty means "no barcode", which is what puts it on the Price List.
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        target.barcode = trimmedBarcode.isEmpty ? nil : trimmedBarcode

        target.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}
