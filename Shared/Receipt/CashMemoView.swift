import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One page of the printed memo, laid out to match the Cash Memer reference PDF
/// exactly: 600pt-wide cream sheet on a warm grey margin, navy title, black body,
/// and the double/single rule rhythm that separates each block.
///
/// Every receipt is two pages:
///
/// - **Page 1 — the customer's copy.** The sale, the customer's *name*, Note 1 and
///   the GPS-captured Saved Location.
/// - **Page 2 — the full record.** Swaps in the private blocks: full Customer
///   Details (name, phone, email, address), Note 2 and the Issuer Account.
struct CashMemoView: View {
    enum Style {
        /// Condensed card for the New Receipt preview pane.
        case preview
        /// Full 600pt sheet used for PDF export and the detail viewer.
        case full
    }

    enum Page: Int, CaseIterable, Identifiable {
        case one = 1, two = 2

        var id: Int { rawValue }

        /// Page 2 carries what the customer's copy must not.
        var isPrivate: Bool { self == .two }
    }

    let memo: MemoSnapshot
    var style: Style = .full
    var page: Page = .one

    @Environment(\.appLanguage) private var language

    /// The reference sheet is 600pt wide; the preview renders the same layout smaller.
    private var s: CGFloat { style == .preview ? 0.6 : 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            doubleRule
            metadata
            doubleRule

            itemTable
            totals

            doubleRule
            cashBlock
            doubleRule

            if page.isPrivate {
                // Page 2 swaps Note 1 and the location for the private blocks.
                if !memo.trimmedNoteTwo.isEmpty {
                    labelledBlock(L10n.string(.notePageTwoLabel, language: language)) {
                        Text(memo.trimmedNoteTwo)
                    }
                    singleRule
                }
                if memo.hasIssuer {
                    issuerBlock
                }
            } else {
                if !memo.trimmedNote.isEmpty {
                    labelledBlock(L10n.string(.note, language: language)) {
                        Text(memo.trimmedNote)
                    }
                    singleRule
                }
                if memo.hasLocation {
                    locationBlock
                    singleRule
                }
            }

            signatureRow
            doubleRule
            qrBlock
            footer
        }
        .padding(.horizontal, 30 * s)
        .padding(.top, 22 * s)
        .padding(.bottom, 30 * s)
        .frame(maxWidth: .infinity)
        .background(MemoPalette.sheet)
        .padding(8 * s)
        .background(MemoPalette.margin)
        .foregroundColor(MemoPalette.ink)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10 * s) {
            Text(page.isPrivate
                 ? "\(L10n.string(.cashMemo, language: language)) (\(L10n.string(.pageTwo, language: language)))"
                 : L10n.string(.cashMemo, language: language))
                .font(.system(size: 34 * s, weight: .bold))
                .foregroundColor(MemoPalette.title)
                .multilineTextAlignment(.center)

            if !memo.headerSubtitle.isEmpty {
                Text(memo.headerSubtitle)
                    .font(.system(size: 15 * s, weight: .semibold))
                    .foregroundColor(MemoPalette.subtitle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 32 * s)
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(spacing: 0) {
            pairRow(
                L10n.string(.receiptNo, language: language), memo.displayNumber,
                L10n.string(.date, language: language), memo.dateText
            )
            pairRow(
                L10n.string(.placeStore, language: language), memo.headerSubtitle,
                L10n.string(.time, language: language), memo.timeText
            )
            pairRow(
                L10n.string(.category, language: language), L10n.string(memo.category.key, language: language),
                L10n.string(.method, language: language), L10n.string(memo.paymentMethod.key, language: language)
            )

            if page.isPrivate {
                // Full contact block, indented under its own heading.
                labelRow(L10n.string(.customerDetails, language: language) + ":")
                if !memo.customerName.isEmpty {
                    indentedRow(L10n.string(.name, language: language), memo.customerName)
                }
                if !memo.customerPhone.isEmpty {
                    indentedRow(L10n.string(.phone, language: language), memo.customerPhone)
                }
                if !memo.customerEmail.isEmpty {
                    indentedRow(L10n.string(.email, language: language), memo.customerEmail)
                }
                if !memo.customerAddress.isEmpty {
                    indentedRow(L10n.string(.address, language: language), memo.customerAddress)
                }
            } else if !memo.customerName.isEmpty {
                // The customer copy names them, but carries no contact details.
                labelRow("\(L10n.string(.customer, language: language)): \(memo.customerName)")
            }
        }
        .padding(.vertical, 12 * s)
    }

    private func pairRow(_ l1: String, _ v1: String, _ l2: String, _ v2: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8 * s) {
            Text("\(l1): \(v1)")
            Spacer(minLength: 8 * s)
            Text("\(l2): \(v2)")
        }
        .font(bodyFont)
        .padding(.vertical, 8.5 * s)
    }

    private func labelRow(_ text: String) -> some View {
        Text(text)
            .font(bodyFont)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8.5 * s)
    }

    private func indentedRow(_ label: String, _ value: String) -> some View {
        Text("\(label): \(value)")
            .font(bodyFont)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12 * s)
            .padding(.vertical, 8.5 * s)
    }

    // MARK: - Items

    private var itemTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8 * s) {
                Text(L10n.string(.item, language: language))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.string(.quantity, language: language))
                    .frame(width: 60 * s, alignment: .trailing)
                Text(L10n.string(.total, language: language))
                    .frame(width: 110 * s, alignment: .trailing)
            }
            .font(bodyFont)
            .padding(.vertical, 12 * s)

            singleRule

            VStack(spacing: 0) {
                ForEach(memo.lines) { line in
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack(spacing: 8 * s) {
                            Text(line.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(line.quantity)")
                                .frame(width: 60 * s, alignment: .trailing)
                            Text(CurrencyFormatter.string(line.total, currency: memo.currency))
                                .frame(width: 110 * s, alignment: .trailing)
                        }
                        .font(bodyFont)

                        // Unit price only earns a line when more than one was sold.
                        if line.quantity > 1 {
                            Text("@ \(CurrencyFormatter.tight(line.unitPrice, currency: memo.currency)) \(L10n.string(.each, language: language))")
                                .font(.system(size: 12 * s, weight: .regular))
                                .foregroundColor(MemoPalette.muted)
                        }
                    }
                    .padding(.vertical, 12 * s)
                }
            }

            singleRule
        }
    }

    // MARK: - Totals

    private var totals: some View {
        VStack(spacing: 0) {
            amountRow(L10n.string(.subtotal, language: language) + ":",
                      CurrencyFormatter.string(memo.totals.subtotal, currency: memo.currency))

            if memo.totals.discount > 0 {
                amountRow(L10n.string(.discount, language: language) + ":",
                          "- " + CurrencyFormatter.string(memo.totals.discount, currency: memo.currency))
            }
            if memo.totals.tax > 0 {
                amountRow("\(L10n.string(.tax, language: language)) (\(memo.taxPercentText)%):",
                          "+ " + CurrencyFormatter.string(memo.totals.tax, currency: memo.currency))
            }

            singleRule

            HStack {
                Text(L10n.string(.grandTotal, language: language) + ":")
                    .font(.system(size: 22 * s, weight: .bold))
                Spacer(minLength: 12 * s)
                Text(CurrencyFormatter.string(memo.totals.grandTotal, currency: memo.currency))
                    .font(.system(size: 17 * s, weight: .bold))
            }
            .padding(.vertical, 13 * s)
        }
    }

    private var cashBlock: some View {
        VStack(spacing: 0) {
            amountRow(L10n.string(.cashGiven, language: language) + ":",
                      CurrencyFormatter.string(memo.totals.cashGiven, currency: memo.currency))
            amountRow(L10n.string(.changeAmount, language: language) + ":",
                      CurrencyFormatter.string(memo.totals.change, currency: memo.currency))
        }
    }

    private func amountRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12 * s)
            Text(value)
        }
        .font(bodyFont)
        .padding(.vertical, 8.5 * s)
    }

    // MARK: - Notes, location, issuer

    private var locationBlock: some View {
        labelledBlock(L10n.string(.savedLocation, language: language)) {
            VStack(alignment: .leading, spacing: 4 * s) {
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
        labelledBlock(L10n.string(.issuerAccount, language: language)) {
            VStack(alignment: .leading, spacing: 4 * s) {
                if !memo.issuedByName.isEmpty {
                    Text("\(L10n.string(.name, language: language)): \(memo.issuedByName)")
                }
                if !memo.issuedByEmail.isEmpty {
                    Text("\(L10n.string(.email, language: language)): \(memo.issuedByEmail)")
                }
            }
        }
    }

    /// `Label:` on its own line, value indented beneath it.
    private func labelledBlock<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10 * s) {
            Text(label + ":")
                .font(bodyFont)
            content()
                .font(bodyFont)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12 * s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Signature, QR, footer

    private var signatureRow: some View {
        HStack(alignment: .center) {
            Text(L10n.string(.authorizedSignature, language: language) + ":")
                .font(bodyFont)
            Spacer(minLength: 12 * s)
            signatureImage
                .frame(width: 140 * s, height: 68 * s)
                .background(Color.white)
        }
        .padding(.vertical, 10 * s)
    }

    @ViewBuilder
    private var signatureImage: some View {
        #if canImport(UIKit)
        if let data = memo.signaturePNG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(4 * s)
        }
        #endif
    }

    private var qrBlock: some View {
        VStack(spacing: 14 * s) {
            if let qr = QRCode.image(for: memo.qrPayload, size: 240) {
                qr
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 76 * s, height: 76 * s)
                    .padding(22 * s)
                    .background(Color.white)
            }
            Text(L10n.string(.scanQRForDetails, language: language))
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundColor(MemoPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20 * s)
    }

    private var footer: some View {
        Text(L10n.string(.thankYouForShopping, language: language))
            .font(.system(size: 16 * s, weight: .semibold))
            .foregroundColor(MemoPalette.muted)
            .padding(.top, 14 * s)
    }

    // MARK: - Rules

    /// The heavy pair that separates the memo's major blocks.
    private var doubleRule: some View {
        VStack(spacing: 2 * s) {
            Rectangle().frame(height: 2 * s)
            Rectangle().frame(height: 2 * s)
        }
        .foregroundColor(MemoPalette.ink)
    }

    /// Single rule used inside the item table and between the lower blocks.
    private var singleRule: some View {
        Rectangle()
            .frame(height: 2 * s)
            .foregroundColor(MemoPalette.ink)
    }

    private var bodyFont: Font { .system(size: 17 * s, weight: .bold) }
}

/// Colours sampled from the reference PDF, fixed rather than theme-aware so the
/// exported document looks identical in light and dark mode.
enum MemoPalette {
    static let margin = Color(hex: 0xDCDCD2)
    static let sheet = Color(hex: 0xFAF9F6)
    static let ink = Color(hex: 0x000000)
    static let title = Color(hex: 0x102C57)
    static let subtitle = Color(hex: 0x505050)
    static let muted = Color(hex: 0x646464)
}
