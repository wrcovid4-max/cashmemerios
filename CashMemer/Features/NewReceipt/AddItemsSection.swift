import SwiftUI

/// The `Item Name | Qty | Price | +` entry row plus the running list of added lines.
struct AddItemsSection: View {
    @ObservedObject var draft: ReceiptDraft

    @Environment(\.appLanguage) private var language

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var priceText = ""

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        FormSection(titleKey: .addItems) {
            VStack(spacing: 0) {
                entryRow

                if !draft.lines.isEmpty {
                    Divider().padding(.leading, Theme.Spacing.l)
                    ForEach(Array(draft.lines.enumerated()), id: \.element.id) { index, line in
                        lineRow(line, isLast: index == draft.lines.count - 1)
                    }
                }
            }
        }
    }

    private var entryRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField(L10n.string(.itemName, language: language), text: $name)
                .frame(maxWidth: .infinity)

            TextField("1", text: $quantityText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 46)
                .padding(.vertical, 7)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField(L10n.string(.price, language: language), text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 82)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canAdd ? Theme.brand : Theme.brand.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .accessibilityLabel(L10n.string(.addItems, language: language))
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
    }

    private func lineRow(_ line: ReceiptDraft.DraftLine, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(line.quantity) × \(CurrencyFormatter.string(line.unitPrice, currency: draft.currency))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(CurrencyFormatter.string(line.unitPrice * Decimal(line.quantity), currency: draft.currency))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Button {
                    draft.lines.removeAll { $0.id == line.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(Theme.destructive.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string(.delete, language: language))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)

            if !isLast {
                Divider().padding(.leading, Theme.Spacing.l)
            }
        }
    }

    private func add() {
        draft.addLine(
            name: name,
            quantity: Int(quantityText) ?? 1,
            unitPrice: Decimal(string: priceText) ?? 0
        )
        name = ""
        quantityText = "1"
        priceText = ""
    }
}
