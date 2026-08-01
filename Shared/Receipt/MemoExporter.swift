import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

/// Rasterises `CashMemoView` into shareable files.
@MainActor
enum MemoExporter {
    /// Width of the exported sheet in points — roughly a wide thermal receipt,
    /// which keeps the memo legible without wasting paper on A4.
    static let pageWidth: CGFloat = 420

    static func pngData(for memo: MemoSnapshot, language: AppLanguage, scale: CGFloat = 3) -> Data? {
        let renderer = ImageRenderer(content: memoContent(memo, language: language))
        renderer.scale = scale
        renderer.isOpaque = true
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #else
        return nil
        #endif
    }

    /// Writes a single-page PDF sized to the memo's natural height.
    static func pdfData(for memo: MemoSnapshot, language: AppLanguage) -> Data? {
        let renderer = ImageRenderer(content: memoContent(memo, language: language))
        renderer.scale = 1

        let data = NSMutableData()
        var succeeded = false

        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: data),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            succeeded = true
        }

        return succeeded && data.length > 0 ? data as Data : nil
    }

    /// Writes the memo to a temporary PDF and returns its URL, ready for a share sheet.
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

    private static func memoContent(_ memo: MemoSnapshot, language: AppLanguage) -> some View {
        CashMemoView(memo: memo, style: .full)
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
