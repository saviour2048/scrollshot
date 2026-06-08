import AppKit
import CoreGraphics

private extension CGPoint {
    func offset(_ delta: CGSize) -> CGPoint {
        CGPoint(x: x + delta.width, y: y + delta.height)
    }
}

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
        /// A text box: the string is wrapped/clipped inside `rect`.
        case text(rect: CGRect, string: String, fontSize: CGFloat)
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

        case let .text(rect, string, fontSize):
            guard !string.isEmpty else { return }
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            // Wraps within the box width and across explicit newlines.
            (string as NSString).draw(in: rect, withAttributes: attributes)

        case let .mosaic(rect):
            guard let pixelatedImage else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: rect).addClip()
            pixelatedImage.draw(in: fullBounds)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// The axis-aligned bounds of the annotation in canvas points.
    var boundingBox: CGRect {
        switch shape {
        case let .arrow(from, to):
            return CGRect(x: min(from.x, to.x), y: min(from.y, to.y),
                          width: abs(from.x - to.x), height: abs(from.y - to.y))
        case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
            return rect
        case let .pen(points):
            guard let first = points.first else { return .zero }
            var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
            for point in points {
                minX = min(minX, point.x); minY = min(minY, point.y)
                maxX = max(maxX, point.x); maxY = max(maxY, point.y)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case let .text(rect, _, _):
            return rect
        }
    }

    /// Whether `point` lands on the annotation (used to grab it for dragging).
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let tol = max(tolerance, lineWidth + 4)
        switch shape {
        case let .arrow(from, to):
            return Annotation.distance(point, toSegment: from, to) <= tol
        case let .pen(points):
            guard points.count > 1 else { return false }
            for i in 0..<(points.count - 1) where
                Annotation.distance(point, toSegment: points[i], points[i + 1]) <= tol {
                return true
            }
            return false
        case let .rectangle(rect), let .ellipse(rect):
            // Grab near the outline; for small shapes the whole box is grabbable.
            let outer = rect.insetBy(dx: -tol, dy: -tol)
            let inner = rect.insetBy(dx: tol, dy: tol)
            guard outer.contains(point) else { return false }
            return inner.width <= 0 || inner.height <= 0 || !inner.contains(point)
        case let .mosaic(rect):
            return rect.contains(point)
        case let .text(rect, _, _):
            return rect.insetBy(dx: -tol, dy: -tol).contains(point)
        }
    }

    /// A copy translated by `delta`.
    func translated(by delta: CGSize) -> Annotation {
        var copy = self
        switch shape {
        case let .arrow(from, to):
            copy.shape = .arrow(from: from.offset(delta), to: to.offset(delta))
        case let .rectangle(rect):
            copy.shape = .rectangle(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .ellipse(rect):
            copy.shape = .ellipse(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .mosaic(rect):
            copy.shape = .mosaic(rect.offsetBy(dx: delta.width, dy: delta.height))
        case let .pen(points):
            copy.shape = .pen(points.map { $0.offset(delta) })
        case let .text(rect, string, fontSize):
            copy.shape = .text(rect: rect.offsetBy(dx: delta.width, dy: delta.height), string: string, fontSize: fontSize)
        }
        return copy
    }

    /// Distance from a point to a line segment.
    static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared
        t = max(0, min(1, t))
        let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - proj.x, p.y - proj.y)
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
