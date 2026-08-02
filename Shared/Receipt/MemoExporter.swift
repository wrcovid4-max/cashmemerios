import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

/// Rasterises `CashMemoView` into shareable files.
///
/// Every memo exports as a two-page PDF: page 1 is the customer copy, page 2 the
/// full record. Pages are sized independently, because page 2 always runs longer.
@MainActor
enum MemoExporter {
    /// Width of the exported sheet in points, matching the reference memo exactly.
    static let pageWidth: CGFloat = 600

    static func pdfData(for memo: MemoSnapshot, language: AppLanguage) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }

        // The context needs a media box up front; each page then overrides it.
        var defaultBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * 2)
        guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else { return nil }

        for page in CashMemoView.Page.allCases {
            let renderer = ImageRenderer(content: content(memo, language: language, page: page))
            renderer.scale = 1

            renderer.render { size, renderInContext in
                let box = CGRect(origin: .zero, size: size)
                let boxData = withUnsafeBytes(of: box) { Data($0) } as CFData
                context.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
                renderInContext(context)
                context.endPDFPage()
            }
        }

        context.closePDF()
        return data.length > 0 ? data as Data : nil
    }

    /// Single page as a PNG — used when sharing an image rather than a document.
    static func pngData(
        for memo: MemoSnapshot,
        language: AppLanguage,
        page: CashMemoView.Page = .one,
        scale: CGFloat = 3
    ) -> Data? {
        let renderer = ImageRenderer(content: content(memo, language: language, page: page))
        renderer.scale = scale
        renderer.isOpaque = true
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #else
        return nil
        #endif
    }

    /// Writes the memo to a temporary two-page PDF, ready for a share sheet.
    static func pdfFile(for memo: MemoSnapshot, language: AppLanguage) throws -> URL {
        guard let data = pdfData(for: memo, language: language) else {
            throw ExportError.renderFailed
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: memo))
            .appendingPathExtension(for: .pdf)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// `Receipt #41 - Mart (Example) - 20260801_22_32_29 - Cash Memer`
    ///
    /// The timestamp is the moment of export, not the receipt's own time, which is
    /// what the reference exports do — sharing the same memo twice gives two files.
    static func fileName(for memo: MemoSnapshot, exportedAt: Date = Date()) -> String {
        let store = memo.headerSubtitle.isEmpty ? "Receipt" : memo.headerSubtitle
        let stamp = stampFormatter.string(from: exportedAt)
        let raw = "Receipt \(memo.displayNumber) - \(store) - \(stamp) - Cash Memer"
        // "/" and ":" are the only characters a file name cannot carry.
        return raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HH_mm_ss"
        return formatter
    }()

    private static func content(
        _ memo: MemoSnapshot,
        language: AppLanguage,
        page: CashMemoView.Page
    ) -> some View {
        CashMemoView(memo: memo, style: .full, page: page)
            .frame(width: pageWidth)
            .appLanguage(language)
            .environment(\.colorScheme, .light)
    }

    enum ExportError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed: return "The memo could not be rendered for export."
            }
        }
    }
}
