import AppKit
import CoreGraphics

enum ImageUtilsError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "无法编码为 PNG。"
        }
    }
}

/// Image conversion / export helpers. (Stitching itself arrives in M3.)
enum ImageUtils {
    static func nsImage(from cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    static func pngData(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    static func savePNG(_ cgImage: CGImage, to url: URL) throws {
        guard let data = pngData(from: cgImage) else { throw ImageUtilsError.encodingFailed }
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    static func copyToPasteboard(_ cgImage: CGImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([nsImage(from: cgImage)])
    }
}
