import PencilKit
import SwiftUI
import UIKit

/// Signature capture backed by PencilKit.
///
/// PKCanvasView gives Apple Pencil pressure, tilt and palm rejection for free, and
/// `drawingPolicy = .anyInput` keeps finger — and simulator mouse — signing working.
struct SignaturePadView: View {
    @Binding var signaturePNG: Data?
    @Binding var saveAsDefault: Bool

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.appLanguage) private var language

    /// Bumped to tell the canvas to wipe itself. The canvas otherwise owns its own
    /// drawing outright — see SignatureCanvas for why it is not a two-way binding.
    @State private var clearToken = 0
    @State private var hasInk = false
    @State private var isPencilOnly = false

    private var hasSignature: Bool { signaturePNG != nil || hasInk }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header

            SignatureCanvas(
                clearToken: clearToken,
                isPencilOnly: isPencilOnly,
                onChange: rasterise
            )
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

            // Always shown, not only once something has been drawn. The form's own
            // Clear button deliberately leaves the signature alone, so this is the
            // only way to remove one and it needs to be findable before you start.
            Button(action: clear) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "trash")
                    Text(L10n.string(.clearSignature, language: language))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundColor(hasSignature ? Theme.destructive : Theme.textTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .stroke(
                            (hasSignature ? Theme.destructive : Theme.textTertiary).opacity(0.4),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasSignature)
        }
        .padding(Theme.Spacing.l)
        .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .onAppear(perform: restoreIfNeeded)
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
        if !hasInk, let data = signaturePNG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
                .allowsHitTesting(false)
        } else if !hasInk {
            Text(L10n.string(.signHere, language: language))
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .padding(12)
                .allowsHitTesting(false)
        }
    }

    /// Restores the signature that was on screen before the view went away — a tab
    /// switch, or the app being quit. Falls back to the saved default.
    private func restoreIfNeeded() {
        guard signaturePNG == nil else { return }
        signaturePNG = settings.draftSignaturePNG ?? settings.defaultSignaturePNG
    }

    private func clear() {
        clearToken += 1
        hasInk = false
        signaturePNG = nil
        settings.draftSignaturePNG = nil
    }

    private func rasterise(_ drawing: PKDrawing) {
        hasInk = !drawing.strokes.isEmpty
        guard hasInk else { return }

        // Crop to the ink so the memo does not print a mostly-empty box.
        let bounds = drawing.bounds.insetBy(dx: -8, dy: -8)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let image = drawing.image(from: bounds, scale: 3)
        guard let data = image.pngData() else { return }

        signaturePNG = data
        settings.draftSignaturePNG = data
        if saveAsDefault { settings.defaultSignaturePNG = data }
    }
}

/// `PKCanvasView` bridged into SwiftUI, reporting each finished stroke.
///
/// The drawing is deliberately **not** a two-way binding. It was, and it made the
/// pad impossible to sign on: the coordinator captured the wrapper struct once at
/// `makeCoordinator()` and kept writing through that stale copy, so the new stroke
/// never reached SwiftUI's state. The next `updateUIView` then saw a canvas whose
/// drawing differed from the (still empty) state and "corrected" the canvas by
/// wiping it. Every stroke was erased a frame after it was drawn.
///
/// So the canvas owns its drawing. SwiftUI is told about changes through `onChange`
/// and can only ever wipe it, by bumping `clearToken`.
private struct SignatureCanvas: UIViewRepresentable {
    let clearToken: Int
    let isPencilOnly: Bool
    let onChange: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.drawingPolicy = isPencilOnly ? .pencilOnly : .anyInput
        // The signature box is a fixed size; scrolling it would fight the gesture.
        canvas.isScrollEnabled = false
        context.coordinator.lastClearToken = clearToken
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Refreshed every update so the callback is never a stale capture.
        context.coordinator.onChange = onChange
        canvas.drawingPolicy = isPencilOnly ? .pencilOnly : .anyInput

        if context.coordinator.lastClearToken != clearToken {
            context.coordinator.lastClearToken = clearToken
            canvas.drawing = PKDrawing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (PKDrawing) -> Void
        var lastClearToken = 0

        init(onChange: @escaping (PKDrawing) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}
