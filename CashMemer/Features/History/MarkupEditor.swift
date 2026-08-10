import PDFKit
import SwiftUI
import UIKit

/// The tool picked in the markup bar.
enum MarkupTool: String, CaseIterable, Identifiable {
    case move, text, check, cross

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .text: return "textformat"
        case .check: return "checkmark"
        case .cross: return "xmark"
        }
    }
}

/// `PDFView` with markup gestures attached.
///
/// A tap places a mark, or picks one up when the move tool is active; a drag
/// moves whatever was picked up. Both report back in page-relative fractions,
/// so the caller never has to know anything about PDF coordinate space.
struct MarkupPDFView: UIViewRepresentable {
    let document: PDFDocument
    let tool: MarkupTool
    let isEditing: Bool
    /// Two-way: the toolbar drives it, and scrolling reports back.
    @Binding var pageIndex: Int
    /// Page index, plus x and y as 0…1 fractions of that page.
    let onTap: (Int, Double, Double) -> Void
    let onDrag: (Int, Double, Double) -> Void

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        view.usePageViewController(false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        // PDFView has gestures of its own; letting both run keeps zoom working.
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        context.coordinator.pdfView = view
        context.coordinator.panRecognizer = pan
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if view.document !== document {
            view.document = document
            view.autoScales = true
        }
        // Only jump when the binding names a different page than the one on
        // screen, or every scroll would be yanked back.
        if let target = document.page(at: pageIndex), view.currentPage !== target {
            view.go(to: target)
        }
        // Panning is only ever wanted while dragging a mark; the rest of the time
        // it would fight PDFView's own scrolling.
        context.coordinator.panRecognizer?.isEnabled = isEditing && tool == .move
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: MarkupPDFView
        weak var pdfView: PDFView?
        weak var panRecognizer: UIPanGestureRecognizer?

        init(parent: MarkupPDFView) {
            self.parent = parent
        }

        /// Never swallow PDFView's own gestures — scrolling and zooming keep working.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard parent.isEditing, let located = locate(recognizer) else { return }
            parent.onTap(located.page, located.x, located.y)
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.isEditing, parent.tool == .move else { return }
            switch recognizer.state {
            case .changed, .ended:
                guard let located = locate(recognizer) else { return }
                parent.onDrag(located.page, located.x, located.y)
            default:
                break
            }
        }

        /// Screen point → page index and 0…1 fractions of that page's media box.
        private func locate(_ recognizer: UIGestureRecognizer) -> (page: Int, x: Double, y: Double)? {
            guard
                let view = pdfView,
                let document = view.document
            else { return nil }

            let point = recognizer.location(in: view)
            guard
                let page = view.page(for: point, nearest: true),
                let index = document.index(for: page) as Int?
            else { return nil }

            let inPage = view.convert(point, to: page)
            let box = page.bounds(for: .mediaBox)
            guard box.width > 0, box.height > 0 else { return nil }

            return (
                index,
                Double((inPage.x - box.minX) / box.width),
                Double((inPage.y - box.minY) / box.height)
            )
        }
    }
}

/// The bar along the bottom: tools, undo, delete, and a page switcher.
struct MarkupToolbar: View {
    @Binding var tool: MarkupTool
    @Binding var pageIndex: Int
    let pageCount: Int
    let canUndo: Bool
    let hasSelection: Bool
    let onUndo: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack {
                Text(L10n.string(.markupTools, language: language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string(.done, language: language))
            }

            HStack(spacing: Theme.Spacing.s) {
                ForEach(MarkupTool.allCases) { option in
                    Button {
                        tool = option
                    } label: {
                        Image(systemName: option.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .foregroundColor(tool == option ? .white : Theme.textPrimary)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .fill(tool == option ? Theme.brand : Theme.cardAlt)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 42)
                        .foregroundColor(canUndo ? Theme.textPrimary : Theme.textTertiary)
                        .background(Theme.cardAlt, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canUndo)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 42)
                        .foregroundColor(hasSelection ? Theme.destructive : Theme.textTertiary)
                        .background(Theme.destructiveSoft.opacity(hasSelection ? 1 : 0.4), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!hasSelection)
            }

            if pageCount > 1 {
                HStack(spacing: Theme.Spacing.s) {
                    Button {
                        pageIndex = max(0, pageIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex == 0)

                    ForEach(0..<pageCount, id: \.self) { index in
                        Button {
                            pageIndex = index
                        } label: {
                            Text("\(L10n.string(.pageLabel, language: language)) \(index + 1)")
                                .font(.subheadline.weight(pageIndex == index ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .foregroundColor(pageIndex == index ? .white : Theme.textSecondary)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                        .fill(pageIndex == index ? Theme.brand : Theme.cardAlt)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        pageIndex = min(pageCount - 1, pageIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(pageIndex >= pageCount - 1)
                }
                .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
    }
}
