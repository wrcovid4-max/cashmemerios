import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

enum QRCode {
    private static let context = CIContext()

    /// Renders `string` as a crisp QR image at `size` points.
    /// Returns `nil` only if Core Image cannot build the code at all.
    static func image(for string: String, size: CGFloat) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        // "M" keeps the code readable after printing without bloating the module count.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        // Core Image emits roughly one pixel per module; scale up before rasterising
        // so the exported PDF does not show a blurry code.
        let scale = max(size / output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return Image(decorative: cgImage, scale: 1)
        #endif
    }
}
