import UIKit
import PDFKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case images = "Images"
    var id: String { rawValue }

    func title(pageCount: Int) -> String {
        switch self {
        case .pdf: "PDF"
        case .images: pageCount == 1 ? "Image" : "Images"
        }
    }
}

/// Writes scanned pages to a temporary folder so the system share sheet can hand
/// them to any app, Files, or Photos. The folder is deleted when the scan is discarded.
enum ScanExport {
    static let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("Scanny-Export", isDirectory: true)

    static func files(for pages: [UIImage], format: ExportFormat, name: String) -> [URL] {
        let base = NameTemplate.fileSafe(name)
        clear()
        guard !pages.isEmpty else { return [] }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        switch format {
        case .pdf:
            let document = PDFDocument()
            for (index, image) in pages.enumerated() {
                if let page = PDFPage(image: image) {
                    document.insert(page, at: index)
                }
            }
            let url = folder.appendingPathComponent("\(base).pdf")
            return document.write(to: url) ? [url] : []

        case .images:
            // Index starts at 1 and is padded to the width of the page count
            // (1–9 pages: 1, 2…; up to 99: 01, 02…; up to 999: 001, 002…).
            let width = String(pages.count).count
            return pages.enumerated().compactMap { index, image in
                let number = String(format: "%0\(width)d", index + 1)
                guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
                let url = folder.appendingPathComponent("\(base)-\(number).jpg")
                return (try? data.write(to: url)) != nil ? url : nil
            }
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: folder)
    }
}
