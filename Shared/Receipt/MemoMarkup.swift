import Foundation
import PDFKit
import UIKit

/// Marks drawn on top of a generated memo — a note, a tick, a cross.
///
/// Stored as coordinates rather than as a flattened PDF. The memo is re-rendered
/// from Core Data every time it is opened, so a saved image would go stale the
/// moment a line item changed. Positions are fractions of the page box, which
/// means a mark keeps its place even when the memo grows a row and the page gets
/// taller.
struct MemoMarkup: Codable, Equatable {
    struct Mark: Codable, Equatable, Identifiable {
        enum Kind: String, Codable {
            case text, check, cross
        }

        var id = UUID()
        var pageIndex: Int
        /// 0…1 across the page, left to right.
        var x: Double
        /// 0…1 up the page, bottom to top — PDF coordinates, not screen ones.
        var y: Double
        var kind: Kind
        var text: String = ""
    }

    var marks: [Mark] = []

    var isEmpty: Bool { marks.isEmpty }

    // MARK: - Storage

    static func decode(_ json: String?) -> MemoMarkup {
        guard
            let json = json,
            let data = json.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(MemoMarkup.self, from: data)
        else { return MemoMarkup() }
        return decoded
    }

    func encoded() -> String? {
        guard !marks.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Drawing

    /// Replaces whatever marks are on the document with these.
    ///
    /// Every free-text annotation is cleared first. The generated memo carries
    /// none of its own, so anything found is a mark from a previous pass.
    func apply(to document: PDFDocument) {
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for annotation in page.annotations where annotation.type == "FreeText" {
                page.removeAnnotation(annotation)
            }
        }

        for mark in marks {
            guard
                mark.pageIndex >= 0, mark.pageIndex < document.pageCount,
                let page = document.page(at: mark.pageIndex)
            else { continue }
            page.addAnnotation(Self.annotation(for: mark, on: page))
        }
    }

    static func annotation(for mark: Mark, on page: PDFPage) -> PDFAnnotation {
        let box = page.bounds(for: .mediaBox)
        let size = mark.kind == .text
            ? CGSize(width: 200, height: 28)
            : CGSize(width: 34, height: 34)

        let bounds = CGRect(
            x: box.minX + CGFloat(mark.x) * box.width - size.width / 2,
            y: box.minY + CGFloat(mark.y) * box.height - size.height / 2,
            width: size.width,
            height: size.height
        )

        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = displayText(for: mark)
        annotation.font = UIFont.systemFont(
            ofSize: mark.kind == .text ? 13 : 24,
            weight: mark.kind == .text ? .medium : .bold
        )
        annotation.fontColor = colour(for: mark.kind)
        // Transparent, so a mark sits on the memo rather than blocking it out.
        annotation.color = .clear
        return annotation
    }

    private static func displayText(for mark: Mark) -> String {
        switch mark.kind {
        case .text: return mark.text
        case .check: return "✓"
        case .cross: return "✗"
        }
    }

    private static func colour(for kind: Mark.Kind) -> UIColor {
        switch kind {
        case .text: return .black
        case .check: return UIColor(red: 0.11, green: 0.60, blue: 0.16, alpha: 1)
        case .cross: return UIColor(red: 0.70, green: 0.15, blue: 0.12, alpha: 1)
        }
    }
}
