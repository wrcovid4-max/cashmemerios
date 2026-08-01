import SwiftUI

/// The printed memo. Rendered on screen for the iPad live preview and rasterised
/// unchanged by `MemoExporter`, so what the user previews is what they share.
struct CashMemoView: View {
    enum Style {
        /// Condensed card shown in the New Receipt preview pane.
        case preview
        /// The full memo: cash/change, note, saved location, signature and QR code.
        case full
    }

    let memo: MemoSnapshot
    var style: Style = .full

    @Environment(\.appLanguage) private var language

    private var showsUnitPriceColumn: Bool { style == .preview }

    var body: some View {
        VStack(spacing: 0) {
            header
            MemoRule()
            metadata
            MemoRule()
            itemTable
            totalsBlock

            if style == .full {
                if memo.hasCashDetails { cashBlock }
                if !trimmedNote.isEmpty { noteBlock }
                if !memo.address.isEmpty || memo.coordinateText != nil { locationBlock }
                if memo.signaturePNG != nil { signatureBlock }
                qrBlock
            }

            Text(L10n.string(.thankYouForShopping, language: language))
                .font(.system(size: style == .preview ? 9 : 12, weight: .semibold))
                .foregroundStyle(Theme.memoInk)
                .padding(.top, style == .preview ? 10 : 14)
        }
        .padding(style == .preview ? 16 : 24)
        .background(Theme.memoPaper)
        .foregroundStyle(Theme.memoInk)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text(L10n.string(.cashMemo, language: language))
                .font(.system(size: style == .preview ? 18 : 26, weight: .heavy))
                .foregroundStyle(Theme.memoTitle)
            if !memo.headerSubtitle.isEmpty {
                Text(memo.headerSubtitle)
                    .font(.system(size: style == .preview ? 9 : 13, weight: .semibold))
                    .foregroundStyle(Theme.memoInk.opacity(0.65))
            }
        }
        .padding(.bottom, style == .preview ? 8 : 12)
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(spacing: 3) {
            MemoPairRow(
                leading: (L10n.string(.receiptNo, language: language), memo.number),
                trailing: (L10n.string(.date, language: language), memo.dateText),
                style: style
            )
            if !memo.title.isEmpty {
                MemoPairRow(
                    leading: (L10n.string(.titleField, language: language), memo.title),
                    trailing: (L10n.string(.time, language: language), memo.timeText),
                    style: style
                )
            } else {
                MemoPairRow(
                    leading: (L10n.string(.placeStoreName, language: language), memo.storeName),
                    trailing: (L10n.string(.time, language: language), memo.timeText),
                    style: style
                )
            }
            MemoPairRow(
                leading: (L10n.string(.category, language: language), L10n.string(memo.category.key, language: language)),
                trailing: (L10n.string(.method, language: language), L10n.string(memo.paymentMethod.key, language: language)),
                style: style
            )
            if style == .full, !memo.customerName.isEmpty {
                MemoPairRow(
                    leading: (L10n.string(.customer, language: language), memo.customerName),
                    trailing: nil,
                    style: style
                )
            }
        }
        .padding(.vertical, style == .preview ? 6 : 10)
    }

    // MARK: - Items

    private var itemTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.string(.item, language: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.string(.quantity, language: language))
                    .frame(width: columnWidth, alignment: .trailing)
                if showsUnitPriceColumn {
                    Text(L10n.string(.unitPrice, language: language))
                        .frame(width: columnWidth * 1.6, alignment: .trailing)
                }
                Text(L10n.string(.total, language: language))
                    .frame(width: columnWidth * 1.8, alignment: .trailing)
            }
            .font(.system(size: fontSize, weight: .bold))
            .padding(.vertical, 6)

            MemoDivider()

            ForEach(memo.lines) { line in
                HStack(spacing: 8) {
                    Text(line.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(line.quantity)")
                        .frame(width: columnWidth, alignment: .trailing)
                    if showsUnitPriceColumn {
                        Text(CurrencyFormatter.string(line.unitPrice, currency: memo.currency))
                            .frame(width: columnWidth * 1.6, alignment: .trailing)
                    }
                    Text(CurrencyFormatter.string(line.total, currency: memo.currency))
                        .frame(width: columnWidth * 1.8, alignment: .trailing)
                }
                .font(.system(size: fontSize, weight: .semibold))
                .padding(.vertical, 5)
            }

            MemoDivider()
        }
    }

    // MARK: - Totals

    private var totalsBlock: some View {
        VStack(spacing: 4) {
            MemoAmountRow(
                label: L10n.string(.subtotal, language: language),
                amount: memo.totals.subtotal,
                currency: memo.currency,
                style: style
            )
            if memo.totals.discount > 0 {
                MemoAmountRow(
                    label: L10n.string(.discount, language: language),
                    amount: -memo.totals.discount,
                    currency: memo.currency,
                    style: style
                )
            }
            if memo.totals.tax > 0 {
                MemoAmountRow(
                    label: L10n.string(.tax, language: language),
                    amount: memo.totals.tax,
                    currency: memo.currency,
                    style: style
                )
            }

            MemoRule()
                .padding(.vertical, 2)

            MemoAmountRow(
                label: L10n.string(.grandTotal, language: language) + ":",
                amount: memo.totals.grandTotal,
                currency: memo.currency,
                style: style,
                emphasised: true
            )

            if style == .full { MemoRule().padding(.top, 2) }
        }
        .padding(.vertical, 6)
    }

    private var cashBlock: some View {
        VStack(spacing: 4) {
            MemoAmountRow(
                label: L10n.string(.cashGiven, language: language) + ":",
                amount: memo.totals.cashGiven,
                currency: memo.currency,
                style: style
            )
            MemoAmountRow(
                label: L10n.string(.changeAmount, language: language) + ":",
                amount: memo.totals.change,
                currency: memo.currency,
                style: style
            )
            MemoRule().padding(.top, 4)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Note, location, signature, QR

    private var trimmedNote: String {
        memo.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(.note, language: language) + ":")
                .font(.system(size: fontSize, weight: .bold))
            Text(trimmedNote)
                .font(.system(size: fontSize, weight: .semibold))
                .padding(.leading, 12)
            if !memo.notesPageTwo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(memo.notesPageTwo)
                    .font(.system(size: fontSize - 1))
                    .foregroundStyle(Theme.memoInk.opacity(0.7))
                    .padding(.leading, 12)
            }
            MemoDivider().padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var locationBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(.savedLocation, language: language) + ":")
                .font(.system(size: fontSize, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                if !memo.address.isEmpty {
                    Text(memo.address)
                }
                if let coordinateText = memo.coordinateText {
                    Text("\(L10n.string(.gps, language: language)): \(coordinateText)")
                }
            }
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.leading, 12)
            MemoDivider().padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var signatureBlock: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom) {
                Text(L10n.string(.authorizedSignature, language: language) + ":")
                    .font(.system(size: fontSize, weight: .bold))
                Spacer(minLength: 12)
                signatureImage
                    .frame(width: 150, height: 60)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Theme.memoInk.opacity(0.15), lineWidth: 0.5))
            }
            MemoRule()
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var signatureImage: some View {
        #if canImport(UIKit)
        if let data = memo.signaturePNG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        #endif
    }

    private var qrBlock: some View {
        VStack(spacing: 6) {
            if let qr = QRCode.image(for: memo.qrPayload, size: 220) {
                qr
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 110, height: 110)
                    .padding(8)
                    .background(Color.white)
            }
            Text(L10n.string(.scanQRForDetails, language: language))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.memoInk.opacity(0.6))
        }
        .padding(.top, 8)
    }

    // MARK: - Metrics

    private var fontSize: CGFloat { style == .preview ? 9 : 13 }
    private var columnWidth: CGFloat { style == .preview ? 34 : 56 }
}

// MARK: - Memo primitives

/// The heavy double rule that separates the memo's major blocks.
private struct MemoRule: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().frame(height: 1.2)
            Rectangle().frame(height: 1.2)
        }
        .foregroundStyle(Theme.memoInk)
    }
}

/// Single hairline used inside the item table.
private struct MemoDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(Theme.memoInk.opacity(0.85))
    }
}

/// `Receipt No: 84AC83A` on the left, `Date: 2026-07-03` on the right.
private struct MemoPairRow: View {
    let leading: (String, String)
    let trailing: (String, String)?
    let style: CashMemoView.Style

    private var fontSize: CGFloat { style == .preview ? 9 : 13 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            labelValue(leading)
            Spacer(minLength: 8)
            if let trailing { labelValue(trailing) }
        }
    }

    private func labelValue(_ pair: (String, String)) -> some View {
        HStack(spacing: 4) {
            Text(pair.0 + ":")
                .font(.system(size: fontSize, weight: style == .preview ? .regular : .bold))
                .foregroundStyle(Theme.memoInk.opacity(style == .preview ? 0.6 : 1))
            Text(pair.1)
                .font(.system(size: fontSize, weight: .bold))
        }
    }
}

/// A right-aligned money row such as `GRAND TOTAL:    Rs 350.00`.
private struct MemoAmountRow: View {
    let label: String
    let amount: Decimal
    let currency: Currency
    let style: CashMemoView.Style
    var emphasised: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text(CurrencyFormatter.string(amount, currency: currency))
        }
        .font(.system(
            size: emphasised ? (style == .preview ? 11 : 16) : (style == .preview ? 9 : 13),
            weight: emphasised ? .heavy : .semibold
        ))
    }
}
