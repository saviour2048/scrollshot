import CoreGraphics

/// Stitches a sequence of same-sized frames (captured while the user scrolls a
/// region downward) into one tall image.
///
/// For each new frame it finds the vertical shift `dy` that best aligns the new
/// frame with the previous one (the content scrolled up by `dy`), then appends
/// only the new `dy` rows at the bottom. Matching is done on a 64-px-wide
/// grayscale copy via mean absolute difference (SAD), which is cheap and robust
/// for the ~3 fps capture rate used here.
///
/// Tunables: `matchThreshold` (lower = stricter), `maxShiftRatio`,
/// `minOverlapRatio`. If a stitched result ever looks scrambled, the grayscale
/// row orientation is the first thing to revisit (see `grayscale`).
// Thread-safety is guaranteed by the caller: every access happens serially on a
// single dedicated queue (see LongCaptureController.stitchQueue), so it's safe
// to hand across concurrency boundaries.
final class FrameStitcher: @unchecked Sendable {
    private let grayWidth = 64
    private let rowSampleStep = 3
    private let maxShiftRatio: CGFloat = 0.8
    private let minOverlapRatio: CGFloat = 0.2
    /// Mean per-pixel gray difference (0–255) below which an alignment is accepted.
    private let matchThreshold: Double = 16

    private var strips: [CGImage] = []
    private var prevGray: [UInt8] = []
    private var prevHeight = 0

    private(set) var totalHeight = 0
    private(set) var outputWidth = 0

    var frameCount: Int { strips.count }

    func reset() {
        strips.removeAll()
        prevGray = []
        prevHeight = 0
        totalHeight = 0
        outputWidth = 0
    }

    /// Feeds a freshly captured frame. Returns true if new content was appended.
    @discardableResult
    func add(_ frame: CGImage) -> Bool {
        guard let gray = FrameStitcher.grayscale(frame, width: grayWidth) else { return false }
        let height = frame.height

        if strips.isEmpty {
            strips.append(frame)
            prevGray = gray
            prevHeight = height
            totalHeight = height
            outputWidth = frame.width
            return true
        }

        let (dy, error) = bestShift(newGray: gray, newHeight: height)
        prevGray = gray
        prevHeight = height

        // dy == 0 means no scroll; a high error means we couldn't align (scrolled
        // too fast or wrong direction) — in both cases append nothing.
        guard dy > 0, error <= matchThreshold else { return false }

        let cropY = height - dy
        guard cropY >= 0,
              let strip = frame.cropping(to: CGRect(x: 0, y: cropY, width: frame.width, height: dy))
        else { return false }

        strips.append(strip)
        totalHeight += dy
        return true
    }

    /// Composes all appended strips into a single tall image (top → bottom).
    func result() -> CGImage? {
        guard !strips.isEmpty, outputWidth > 0, totalHeight > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // CGContext origin is bottom-left, so place the first strip at the top.
        var y = totalHeight
        for strip in strips {
            y -= strip.height
            context.draw(strip, in: CGRect(x: 0, y: y, width: outputWidth, height: strip.height))
        }
        return context.makeImage()
    }

    // MARK: Matching

    /// Finds the vertical shift minimizing mean abs difference over the overlap.
    private func bestShift(newGray: [UInt8], newHeight: Int) -> (dy: Int, error: Double) {
        let height = min(prevHeight, newHeight)
        let maxShift = Int(CGFloat(height) * maxShiftRatio)
        let minOverlap = max(1, Int(CGFloat(height) * minOverlapRatio))
        let width = grayWidth

        var bestDy = 0
        var bestError = Double.greatestFiniteMagnitude

        var dy = 0
        while dy <= maxShift {
            let overlap = min(prevHeight - dy, newHeight)
            if overlap >= minOverlap {
                var sum = 0.0
                var count = 0
                var y = 0
                while y < overlap {
                    let prevRow = (y + dy) * width
                    let newRow = y * width
                    var x = 0
                    while x < width {
                        let diff = Int(prevGray[prevRow + x]) - Int(newGray[newRow + x])
                        sum += Double(abs(diff))
                        count += 1
                        x += 1
                    }
                    y += rowSampleStep
                }
                if count > 0 {
                    let error = sum / Double(count)
                    if error < bestError {
                        bestError = error
                        bestDy = dy
                    }
                }
            }
            dy += 1
        }
        return (bestDy, bestError)
    }

    /// Renders `image` to a `width`-wide 8-bit grayscale buffer, full height,
    /// row-major with row 0 at the top.
    static func grayscale(_ image: CGImage, width: Int) -> [UInt8]? {
        let height = image.height
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ),
              let data = context.data
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        return Array(UnsafeBufferPointer(start: buffer, count: width * height))
    }
}
