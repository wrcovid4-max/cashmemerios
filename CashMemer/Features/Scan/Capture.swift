import SwiftUI
import UIKit
import VisionKit

/// Plain camera capture, returning JPEG data ready for the OCR pipeline.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let dismiss: () -> Void

        init(onCapture: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // 0.8 keeps receipts legible to OCR without sending a 5 MB upload.
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

/// Live barcode capture via VisionKit's `DataScannerViewController`.
struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerView { code in
                        onScan(code)
                        dismiss()
                    }
                    .ignoresSafeArea()
                } else {
                    EmptyStateView(
                        systemImage: "barcode.viewfinder",
                        titleKey: .scanBarcode,
                        messageKey: .notEnoughData
                    )
                }
            }
            .navigationTitle(L10n.string(.scanBarcode, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, language: language)) { dismiss() }
                }
            }
        }
    }
}

private struct DataScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        // Starting is a no-op when the scanner is already running.
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var hasReported = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {
            // One barcode per sheet; ignore everything after the first hit.
            guard !hasReported else { return }
            for item in items {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    hasReported = true
                    onScan(value)
                    return
                }
            }
        }
    }
}
