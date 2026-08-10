import PencilKit
import SwiftUI
import UIKit

/// Signature capture backed by PencilKit.
///
/// PKCanvasView gives Apple Pencil pressure, tilt and palm rejection for free, and
/// `drawingPolicy = .anyInput` keeps finger signing working on iPhone.
struct SignaturePadView: View {
    @Binding var signaturePNG: Data?
    @Binding var saveAsDefault: Bool

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    @State private var drawing = PKDrawing()
    @State private var isPencilOnly = false

    private var hasSignature: Bool { signaturePNG != nil || !drawing.strokes.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header

            SignatureCanvas(drawing: $drawing, isPencilOnly: isPencilOnly, onChange: rasterise)
                .frame(height: 170)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(Theme.separator, lineWidth: 1)
                )
                .overlay(alignment: .bottomLeading) { placeholder }

            Toggle(isOn: $saveAsDefault) {
                Text(L10n.string(.saveAsDefaultSignature, language: language))
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
            }
            .tint(Theme.brand)

            if UIDevice.current.userInterfaceIdiom == .pad {
                Toggle(isOn: $isPencilOnly) {
                    Label(L10n.string(.applePencilOnly, language: language), systemImage: "applepencil")
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }
                .tint(Theme.brand)
            }

            if hasSignature {
                Button(action: clear) {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "trash")
                        Text(L10n.string(.clearAndRedraw, language: language))
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundColor(Theme.destructive)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .stroke(Theme.destructive.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .onAppear(perform: loadDefaultIfNeeded)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string(.digitalSignature, language: language))
                    .font(.headline)
                    .foregroundColor(Theme.heading)
                if hasSignature {
                    Text(L10n.string(.signatureHint, language: language))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            if hasSignature {
                Label(
                    L10n.string(.signatureCaptured, language: language),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.brand)
            }
        }
    }

    /// Shows a previously saved signature until the user starts drawing over it.
    @ViewBuilder
    private var placeholder: some View {
        if drawing.strokes.isEmpty, let data = signaturePNG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
                .allowsHitTesting(false)
        } else if drawing.strokes.isEmpty {
            Text(L10n.string(.signHere, language: language))
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .padding(12)
                .allowsHitTesting(false)
        }
    }

    private func loadDefaultIfNeeded() {
        if signaturePNG == nil { signaturePNG = settings.defaultSignaturePNG }
    }

    private func clear() {
        drawing = PKDrawing()
        signaturePNG = nil
    }

    private func rasterise() {
        guard !drawing.strokes.isEmpty else { return }
        // Crop to the ink so the memo does not print a mostly-empty box.
        let bounds = drawing.bounds.insetBy(dx: -8, dy: -8)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let image = drawing.image(from: bounds, scale: 3)
        guard let data = image.pngData() else { return }

        signaturePNG = data
        if saveAsDefault { settings.defaultSignaturePNG = data }
    }
}

/// `PKCanvasView` bridged into SwiftUI, reporting each finished stroke.
private struct SignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let isPencilOnly: Bool
    let onChange: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.drawingPolicy = isPencilOnly ? .pencilOnly : .anyInput
        // The signature box is fixed size; scrolling it would fight the gesture.
        canvas.isScrollEnabled = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.drawingPolicy = isPencilOnly ? .pencilOnly : .anyInput
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: SignatureCanvas

        init(_ parent: SignatureCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChange()
        }
    }
}
