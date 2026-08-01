import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One page of the printed memo. Rendered on screen for the iPad live preview and
/// rasterised unchanged by `MemoExporter`, so what the user previews is what they share.
///
/// Every receipt is two pages:
///
/// - **Page 1 — customer copy.** Everything except the private block: customer
///   phone, customer email, the saved location/GPS, Note 2 and the issuing account.
///   The customer's *name* is still printed.
/// - **Page 2 — full record.** Everything, including all of the above.
struct CashMemoView: View {
    enum Style {
        /// Condensed card shown in the New Receipt preview pane.
        case preview
        /// Full-size sheet used for PDF export and the detail viewer.
        case full
    }

    enum Page: Int, CaseIterable, Identifiable {
        case one = 1, two = 2

        var id: Int { rawValue }

        /// Only page 2 carries the details the customer should not receive.
        var showsPrivateDetails: Bool { self == .two }

        var labelKey: L10n.Key {
            switch self {
            case .one: return .pageOneOfTwo
            case .two: return .pageTwoOfTwo
            }
        }

        var roleKey: L10n.Key {
            switch self {
            case .one: return .customerCopy
            case .two: return .fullRecord
            }
        }
    }

    let memo: MemoSnapshot
    var style: Style = .full
    var page: Page = .one

    @Environment(\.appLanguage) private var language

    private var showsUnitPriceColumn: Bool { style == .preview }
    private var isPrivate: Bool { page.showsPrivateDetails }

    var body: some View {
        VStack(spacing: 0) {
            header
            MemoRule()
            metadata
            MemoRule()
            itemTable
            totalsBlock

            if memo.hasCashDetails { cashBlock }
            if !memo.trimmedNote.isEmpty { noteBlock }

            // Everything below is withheld from the customer copy.
            if isPrivate {
                if !memo.trimmedNoteTwo.isEmpty { noteTwoBlock }
                if memo.hasLocation { locationBlock }
                if memo.hasIssuer { issuerBlock }
            }

            if memo.signaturePNG != nil { signatureBlock }
            qrBlock
            footer
        }
        .padding(style == .preview ? 16 : 24)
        .background(Theme.memoPaper)
        .foregroundColor(Theme.memoInk)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text(L10n.string(.cashMemo, language: language))
                .font(.system(size: style == .preview ? 18 : 26, weight: .heavy))
                .foregroundColor(Theme.memoTitle)
            if !memo.headerSubtitle.isEmpty {
                Text(memo.headerSubtitle)
                    .font(.system(size: style == .preview ? 9 : 13, weight: .semibold))
                    .foregroundColor(Theme.memoInk.opacity(0.65))
            }
            Text(L10n.string(page.roleKey, language: language))
                .font(.system(size: style == .preview ? 7 : 10, weight: .semibold))
                .foregroundColor(Theme.memoInk.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.8)
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
            // The customer's name appears on both pages; their phone and email do not.
            if !memo.customerName.isEmpty {
                MemoPairRow(
                    leading: (L10n.string(.customer, language: language), memo.customerName),
                    trailing: nil,
                    style: style
                )
            }
            if isPrivate, memo.hasCustomerContact {
                if !memo.customerPhone.isEmpty {
                    MemoPairRow(
                        leading: (L10n.string(.phone, language: language), memo.customerPhone),
                        trailing: nil,
                        style: style
                    )
                }
                if !memo.customerEmail.isEmpty {
                    MemoPairRow(
                        leading: (L10n.string(.email, language: language), memo.customerEmail),
                        trailing: nil,
                        style: style
                    )
                }
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

            MemoRule().padding(.vertical, 2)

            MemoAmountRow(
                label: L10n.string(.grandTotal, language: language) + ":",
                amount: memo.totals.grandTotal,
                currency: memo.currency,
                style: style,
                emphasised: true
            )

            MemoRule().padding(.top, 2)
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

    // MARK: - Notes, location, issuer

    private var noteBlock: some View {
        labelledBlock(L10n.string(.note, language: language)) {
            Text(memo.trimmedNote)
        }
    }

    private var noteTwoBlock: some View {
        labelledBlock(L10n.string(.notesPageTwo, language: language)) {
            Text(memo.trimmedNoteTwo)
        }
    }

    private var locationBlock: some View {
        labelledBlock(L10n.string(.savedLocation, language: language)) {
            VStack(alignment: .leading, spacing: 2) {
                if !memo.address.isEmpty {
                    Text(memo.address)
                }
                if let coordinateText = memo.coordinateText {
                    Text("\(L10n.string(.gps, language: language)): \(coordinateText)")
                }
            }
        }
    }

    private var issuerBlock: some View {
        labelledBlock(L10n.string(.issuedBy, language: language)) {
            VStack(alignment: .leading, spacing: 2) {
                if !memo.issuedByName.isEmpty {
                    Text(memo.issuedByName)
                }
                if !memo.issuedByEmail.isEmpty {
                    Text("\(L10n.string(.accountEmail, language: language)): \(memo.issuedByEmail)")
                }
            }
        }
    }

    /// `Label:` on its own line with an indented value and a closing rule.
    private func labelledBlock<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .font(.system(size: fontSize, weight: .bold))
            content()
                .font(.system(size: fontSize, weight: .semibold))
                .padding(.leading, 12)
            MemoDivider().padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    // MARK: - Signature, QR, footer

    private var signatureBlock: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom) {
                Text(L10n.string(.authorizedSignature, language: language) + ":")
                    .font(.system(size: fontSize, weight: .bold))
                Spacer(minLength: 12)
                signatureImage
                    .frame(width: style == .preview ? 100 : 150, height: style == .preview ? 40 : 60)
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
                    .frame(
                        width: style == .preview ? 66 : 110,
                        height: style == .preview ? 66 : 110
                    )
                    .padding(8)
                    .background(Color.white)
            }
            Text(L10n.string(.scanQRForDetails, language: language))
                .font(.system(size: style == .preview ? 7 : 10, weight: .medium))
                .foregroundColor(Theme.memoInk.opacity(0.6))
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 3) {
            Text(L10n.string(.thankYouForShopping, language: language))
                .font(.system(size: style == .preview ? 9 : 12, weight: .semibold))
                .foregroundColor(Theme.memoInk)
            Text(L10n.string(page.labelKey, language: language))
                .font(.system(size: style == .preview ? 7 : 9))
                .foregroundColor(Theme.memoInk.opacity(0.45))
        }
        .padding(.top, style == .preview ? 10 : 14)
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
        .foregroundColor(Theme.memoInk)
    }
}

/// Single hairline used inside the item table.
private struct MemoDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(Theme.memoInk.opacity(0.85))
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
            if let trailing = trailing { labelValue(trailing) }
        }
    }

    private func labelValue(_ pair: (String, String)) -> some View {
        HStack(spacing: 4) {
            Text(pair.0 + ":")
                .font(.system(size: fontSize, weight: style == .preview ? .regular : .bold))
                .foregroundColor(Theme.memoInk.opacity(style == .preview ? 0.6 : 1))
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
