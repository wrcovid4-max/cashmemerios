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
    /// Width of the exported sheet in points — roughly a wide thermal receipt,
    /// which keeps the memo legible without wasting paper on A4.
    static let pageWidth: CGFloat = 420

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
            .appendingPathComponent("CashMemo-\(memo.number)")
            .appendingPathExtension(for: .pdf)
        try data.write(to: url, options: .atomic)
        return url
    }

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
