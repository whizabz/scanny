import SwiftUI
import PhotosUI
import Vision

/// Turns photos picked from the library into pages. Vision finds the document's
/// corners so the perspective crop starts in the right place; it can be edited after.
enum PhotoImport {
    struct Result {
        let image: UIImage
        let crop: [CGPoint]?
    }

    static func load(_ items: [PhotosPickerItem]) async -> [Result] {
        var results: [Result] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let raw = UIImage(data: data) else { continue }
            let image = upright(raw)
            results.append(Result(image: image, crop: await detectQuad(in: image)))
        }
        return results
    }

    /// Redraws the photo so its pixels match how it is displayed (no EXIF rotation).
    private static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func detectQuad(in image: UIImage) async -> [CGPoint]? {
        guard let cg = image.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> [CGPoint]? in
            let request = VNDetectDocumentSegmentationRequest()
            let handler = VNImageRequestHandler(cgImage: cg)
            guard (try? handler.perform([request])) != nil,
                  let box = request.results?.first, box.confidence > 0.5 else { return nil }
            // Vision's origin is bottom-left; the app's crop uses top-left.
            func p(_ v: CGPoint) -> CGPoint { CGPoint(x: v.x, y: 1 - v.y) }
            return [p(box.topLeft), p(box.topRight), p(box.bottomRight), p(box.bottomLeft)]
        }.value
    }
}
