import UIKit
import CoreImage

enum PageFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "Black & White"
    var id: String { rawValue }
}

/// One scanned page plus the edits applied to it. Edits are always re-applied to
/// the untouched original, so switching filters never degrades the image.
struct PageItem: Identifiable {
    let id = UUID()
    let original: UIImage
    var turns = 0                       // quarter turns clockwise
    var filter: PageFilter = .original
    /// Perspective crop corners (TL, TR, BR, BL), normalised 0...1 with origin top-left.
    var crop: [CGPoint]?
    private(set) var rendered: UIImage

    init(_ image: UIImage) {
        original = image
        rendered = image
    }

    var signature: String { "\(id)-\(turns)-\(filter.rawValue)-\(crop.map { "\($0)" } ?? "")" }

    mutating func rotate() {
        turns = (turns + 1) % 4
        render()
    }

    mutating func rotateLeft() {
        turns = (turns + 3) % 4
        render()
    }

    mutating func setCrop(_ quad: [CGPoint]?) {
        crop = quad
        render()
    }

    mutating func setFilter(_ newFilter: PageFilter) {
        filter = newFilter
        render()
    }

    private mutating func render() {
        rendered = Self.apply(filter, to: Self.rotated(Self.cropped(original, quad: crop), turns: turns))
    }

    private static let context = CIContext()

    /// Straightens the chosen quadrilateral into a rectangle (perspective correction).
    private static func cropped(_ image: UIImage, quad: [CGPoint]?) -> UIImage {
        guard let quad, quad.count == 4, let input = CIImage(image: image) else { return image }
        let w = input.extent.width, h = input.extent.height
        func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * w, y: (1 - p.y) * h) }
        let output = input.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": point(quad[0]), "inputTopRight": point(quad[1]),
            "inputBottomRight": point(quad[2]), "inputBottomLeft": point(quad[3]),
        ])
        guard let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    private static func rotated(_ image: UIImage, turns: Int) -> UIImage {
        guard turns % 4 != 0 else { return image }
        let size = image.size
        let newSize = turns % 2 == 0 ? size : CGSize(width: size.height, height: size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: CGFloat(turns) * .pi / 2)
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                                  width: size.width, height: size.height))
        }
    }

    private static func apply(_ filter: PageFilter, to image: UIImage) -> UIImage {
        guard filter != .original, let input = CIImage(image: image) else { return image }
        let params: [String: Any]
        switch filter {
        case .original: return image
        case .color:         params = [kCIInputSaturationKey: 1.25, kCIInputContrastKey: 1.1]
        case .grayscale:     params = [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 1.1]
        case .blackAndWhite: params = [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 2.2,
                                       kCIInputBrightnessKey: 0.1]
        }
        let output = input.applyingFilter("CIColorControls", parameters: params)
        guard let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
}
