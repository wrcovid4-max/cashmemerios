import CoreSpotlight
import PDFKit
import SwiftUI

/// A saved memo rendered as a real PDF and shown in PDFKit, so pinch-zoom, page
/// thumbnails, text selection and Markup all behave exactly as they do in Files.
struct ReceiptDetailView: View {
    @ObservedObject var receipt: CDReceipt

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    @State private var document: PDFDocument?
    @State private var shareURL: URL?
    @State private var isSharing = false

    private var memo: MemoSnapshot { MemoSnapshot(receipt: receipt) }

    var body: some View {
        Group {
            if let document = document {
                // Deliberately *not* ignoring the bottom safe area. Doing so drew
                // the last of the memo — signature, QR, footer — underneath the
                // tab bar, where it collided with the tab labels and could not be
                // scrolled clear.
                PDFViewer(document: document)
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
        .task(id: receipt.objectID) { await render() }
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
        document = PDFDocument(data: data)
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
