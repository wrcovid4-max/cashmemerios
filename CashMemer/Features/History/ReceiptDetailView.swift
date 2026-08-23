import CoreSpotlight
import PDFKit
import SwiftUI

/// A saved memo rendered as a real PDF and shown in PDFKit, so pinch-zoom, page
/// thumbnails, text selection and Markup all behave exactly as they do in Files.
struct ReceiptDetailView: View {
    @ObservedObject var receipt: CDReceipt

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language
    @Environment(\.managedObjectContext) private var context

    @State private var document: PDFDocument?
    @State private var shareURL: URL?
    @State private var isSharing = false

    // Markup
    @State private var markup = MemoMarkup()
    @State private var isMarkingUp = false
    @State private var tool: MarkupTool = .move
    @State private var pageIndex = 0
    @State private var selectedMark: UUID?
    @State private var pendingTextMark: MemoMarkup.Mark?
    @State private var textEntry = ""

    private var memo: MemoSnapshot { MemoSnapshot(receipt: receipt) }

    var body: some View {
        Group {
            if let document = document {
                // Deliberately *not* ignoring the bottom safe area. Doing so drew
                // the last of the memo — signature, QR, footer — underneath the
                // tab bar, where it collided with the tab labels and could not be
                // scrolled clear.
                MarkupPDFView(
                    document: document,
                    tool: tool,
                    isEditing: isMarkingUp,
                    pageIndex: $pageIndex,
                    onTap: place,
                    onDrag: dragSelected
                )
                .overlay(alignment: .bottom) {
                    if isMarkingUp {
                        MarkupToolbar(
                            tool: $tool,
                            pageIndex: $pageIndex,
                            pageCount: document.pageCount,
                            canUndo: !markup.isEmpty,
                            hasSelection: selectedMark != nil,
                            onUndo: undo,
                            onDelete: deleteSelected,
                            onClose: { isMarkingUp = false }
                        )
                        .padding(Theme.Spacing.m)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isMarkingUp)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(memo.headerSubtitle.isEmpty ? memo.number : memo.headerSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isMarkingUp.toggle()
                    if !isMarkingUp { selectedMark = nil }
                } label: {
                    Image(systemName: isMarkingUp ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                }
                .accessibilityLabel(L10n.string(.markupTools, language: language))

                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.string(.share, language: language))
            }
        }
        .sheet(isPresented: $isSharing) {
            if let shareURL = shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .task(id: receipt.objectID) {
            markup = MemoMarkup.decode(receipt.markupJSON)
            await render()
        }
        .alert(
            L10n.string(.addNote, language: language),
            isPresented: Binding(
                get: { pendingTextMark != nil },
                set: { if !$0 { pendingTextMark = nil } }
            )
        ) {
            TextField(L10n.string(.notes, language: language), text: $textEntry)
            Button(L10n.string(.cancel, language: language), role: .cancel) {
                pendingTextMark = nil
                textEntry = ""
            }
            Button(L10n.string(.save, language: language)) { commitTextMark() }
        }
        // Donating the activity keeps this memo near the top of Spotlight and
        // lets Siri suggest it on the Lock Screen.
        .userActivity(SpotlightIndex.activityType) { activity in
            activity.title = memo.headerSubtitle.isEmpty ? memo.number : memo.headerSubtitle
            activity.userInfo = [CSSearchableItemActivityIdentifier: receipt.id.uuidString]
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.contentAttributeSet = SpotlightIndex.attributeSet(for: receipt)
            activity.webpageURL = nil
            activity.persistentIdentifier = receipt.id.uuidString
        }
    }

    @MainActor
    private func render() async {
        guard let data = MemoExporter.pdfData(for: memo, language: settings.language) else { return }
        let rebuilt = PDFDocument(data: data)
        rebuilt.map { markup.apply(to: $0) }
        document = rebuilt
    }

    // MARK: - Markup

    /// A tap either drops a new mark or, with the move tool, picks up the nearest
    /// one — within a tolerance, since a fingertip is far wider than a tick.
    private func place(page: Int, x: Double, y: Double) {
        switch tool {
        case .move:
            selectedMark = nearestMark(page: page, x: x, y: y)?.id
        case .text:
            pendingTextMark = MemoMarkup.Mark(pageIndex: page, x: x, y: y, kind: .text)
            textEntry = ""
        case .check, .cross:
            markup.marks.append(
                MemoMarkup.Mark(pageIndex: page, x: x, y: y, kind: tool == .check ? .check : .cross)
            )
            persist()
        }
    }

    private func dragSelected(page: Int, x: Double, y: Double) {
        guard let selectedMark = selectedMark,
              let index = markup.marks.firstIndex(where: { $0.id == selectedMark })
        else { return }
        markup.marks[index].pageIndex = page
        markup.marks[index].x = x
        markup.marks[index].y = y
        persist()
    }

    private func commitTextMark() {
        guard var mark = pendingTextMark else { return }
        let trimmed = textEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingTextMark = nil
        textEntry = ""
        guard !trimmed.isEmpty else { return }
        mark.text = trimmed
        markup.marks.append(mark)
        persist()
    }

    private func undo() {
        guard !markup.marks.isEmpty else { return }
        let removed = markup.marks.removeLast()
        if selectedMark == removed.id { selectedMark = nil }
        persist()
    }

    private func deleteSelected() {
        guard let selectedMark = selectedMark else { return }
        markup.marks.removeAll { $0.id == selectedMark }
        self.selectedMark = nil
        persist()
    }

    /// Nearest mark on the same page, within a tenth of the page — close enough
    /// to feel deliberate, loose enough to hit a 34pt tick with a thumb.
    private func nearestMark(page: Int, x: Double, y: Double) -> MemoMarkup.Mark? {
        markup.marks
            .filter { $0.pageIndex == page }
            .map { ($0, hypot($0.x - x, $0.y - y)) }
            .filter { $0.1 < 0.1 }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Writes the marks back and redraws. Saving on every change is cheap — the
    /// payload is a few hundred bytes of JSON — and means nothing is ever lost by
    /// navigating away.
    private func persist() {
        receipt.markupJSON = markup.encoded()
        receipt.updatedAt = Date()
        try? context.save()
        if let document = document { markup.apply(to: document) }
    }

    private func share() {
        guard let url = try? MemoExporter.pdfFile(for: memo, language: settings.language) else { return }
        shareURL = url
        isSharing = true
    }
}

/// `PDFView` bridged into SwiftUI.
struct PDFViewer: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        // A memo is one tall page; continuous single-column keeps scrolling natural.
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        view.usePageViewController(false)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
            view.autoScales = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
