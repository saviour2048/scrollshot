import AppKit
import CoreGraphics

/// The drawing tools available in the overlay toolbar.
enum AnnotationTool: Int, CaseIterable {
    case arrow, rectangle, ellipse, pen, text, mosaic
}

/// A single committed annotation. All geometry is stored in the canvas's
/// flipped (top-left origin) point coordinate space, matching the live view so
/// the same `draw` routine works for both on-screen rendering and export.
struct Annotation {
    enum Shape {
        case arrow(from: CGPoint, to: CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        case pen([CGPoint])
        case text(origin: CGPoint, string: String, fontSize: CGFloat)
        case mosaic(CGRect)
    }

    var shape: Shape
    var color: NSColor
    var lineWidth: CGFloat

    /// Draws into the current graphics context.
    /// - Parameters:
    ///   - pixelatedImage: a fully-pixelated copy of the frozen screenshot,
    ///     sized to `fullBounds`, used to render mosaic regions.
    ///   - fullBounds: the canvas bounds (points), i.e. where the screenshot is drawn.
    func draw(pixelatedImage: NSImage?, fullBounds: CGRect) {
        switch shape {
        case let .arrow(from, to):
            Annotation.drawArrow(from: from, to: to, lineWidth: lineWidth, color: color)

        case let .rectangle(rect):
            let path = NSBezierPath(rect: rect)
            path.lineWidth = lineWidth
            color.setStroke()
            path.stroke()

        case let .ellipse(rect):
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = lineWidth
            color.setStroke()
            path.stroke()

        case let .pen(points):
            guard points.count > 1 else { return }
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.move(to: points[0])
            for point in points.dropFirst() { path.line(to: point) }
            color.setStroke()
            path.stroke()

        case let .text(origin, string, fontSize):
            guard !string.isEmpty else { return }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color
            ]
            (string as NSString).draw(at: origin, withAttributes: attributes)

        case let .mosaic(rect):
            guard let pixelatedImage else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: rect).addClip()
            pixelatedImage.draw(in: fullBounds)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    static func drawArrow(from: CGPoint, to: CGPoint, lineWidth: CGFloat, color: NSColor) {
        color.setStroke()
        color.setFill()

        let shaft = NSBezierPath()
        shaft.lineWidth = lineWidth
        shaft.lineCapStyle = .round
        shaft.move(to: from)
        shaft.line(to: to)
        shaft.stroke()

        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLength = max(12, lineWidth * 3.5)
        let headAngle = CGFloat.pi / 7
        let left = CGPoint(
            x: to.x - headLength * cos(angle - headAngle),
            y: to.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: to.x - headLength * cos(angle + headAngle),
            y: to.y - headLength * sin(angle + headAngle)
        )
        let head = NSBezierPath()
        head.move(to: to)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }
}
