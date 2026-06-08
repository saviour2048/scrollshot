import AppKit
import CoreGraphics

/// Editable canvas for an arbitrary image (e.g. a stitched long screenshot).
/// Same annotation model/behaviour as the overlay, but no region selection —
/// the whole image is editable, and the view scrolls inside a window.
///
/// Geometry: the view is flipped (top-left) and sized in points = pixels/scale,
/// so annotations map to image pixels via `* scale` on export.
final class AnnotationEditorView: NSView, NSTextFieldDelegate {
    private enum Mode { case idle, drawing, moving }

    private let baseCGImage: CGImage
    private let baseImage: NSImage
    private let scale: CGFloat

    private var mode: Mode = .idle
    private var startPoint: CGPoint?
    private var annotations: [Annotation] = []
    private var draft: Annotation?
    private var movingIndex: Int?
    private var lastMovePoint: CGPoint = .zero

    private var currentTool: AnnotationTool?
    private var currentColor: NSColor = .systemRed
    private var currentWidth: CGFloat = 4

    private var activeTextField: NSTextField?
    private var textOrigin: CGPoint = .zero

    private lazy var pixelatedImage: NSImage? = {
        guard let cg = ImageUtils.pixelated(baseCGImage) else { return nil }
        return NSImage(cgImage: cg, size: bounds.size)
    }()

    init(image: CGImage, scale: CGFloat) {
        self.baseCGImage = image
        self.scale = max(1, scale)
        let displaySize = NSSize(width: CGFloat(image.width) / self.scale,
                                 height: CGFloat(image.height) / self.scale)
        self.baseImage = NSImage(cgImage: image, size: displaySize)
        super.init(frame: NSRect(origin: .zero, size: displaySize))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: currentTool == nil ? .arrow : .crosshair)
    }

    // MARK: External controls (wired from the toolbar)

    func selectTool(_ tool: AnnotationTool) { currentTool = tool; window?.invalidateCursorRects(for: self) }
    func setColor(_ color: NSColor) { currentColor = color }
    func setWidth(_ width: CGFloat) { currentWidth = width }

    func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        needsDisplay = true
    }

    @discardableResult
    func save() -> URL? {
        commitActiveText()
        guard let image = outputImage() else { return nil }
        ImageUtils.copyToPasteboard(image)
        return try? ImageUtils.saveToDesktop(image)
    }

    func copy() {
        commitActiveText()
        guard let image = outputImage() else { return }
        ImageUtils.copyToPasteboard(image)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        baseImage.draw(in: bounds)
        for annotation in annotations {
            annotation.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
        }
        draft?.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        commitActiveText()
        let point = convert(event.locationInWindow, from: nil)
        if let index = hitTestAnnotation(at: point) {
            mode = .moving
            movingIndex = index
            lastMovePoint = point
            return
        }
        guard let tool = currentTool else { return }
        if tool == .text {
            beginTextEditing(at: point)
        } else {
            mode = .drawing
            startPoint = point
            draft = initialDraft(tool: tool, at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch mode {
        case .drawing:
            updateDraft(to: point)
            needsDisplay = true
        case .moving:
            moveAnnotation(to: point)
        case .idle:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .drawing, let draft, isValid(draft) {
            annotations.append(draft)
        }
        draft = nil
        startPoint = nil
        movingIndex = nil
        mode = .idle
        needsDisplay = true
    }

    // MARK: Annotation helpers

    private func hitTestAnnotation(at point: CGPoint) -> Int? {
        for index in annotations.indices.reversed() where annotations[index].hitTest(point, tolerance: 8) {
            return index
        }
        return nil
    }

    private func moveAnnotation(to point: CGPoint) {
        guard let index = movingIndex else { return }
        var delta = CGSize(width: point.x - lastMovePoint.x, height: point.y - lastMovePoint.y)
        let box = annotations[index].boundingBox
        delta.width = min(max(delta.width, -box.minX), bounds.width - box.maxX)
        delta.height = min(max(delta.height, -box.minY), bounds.height - box.maxY)
        annotations[index] = annotations[index].translated(by: delta)
        lastMovePoint = point
        needsDisplay = true
    }

    private func initialDraft(tool: AnnotationTool, at point: CGPoint) -> Annotation {
        let shape: Annotation.Shape
        switch tool {
        case .arrow: shape = .arrow(from: point, to: point)
        case .rectangle: shape = .rectangle(CGRect(origin: point, size: .zero))
        case .ellipse: shape = .ellipse(CGRect(origin: point, size: .zero))
        case .mosaic: shape = .mosaic(CGRect(origin: point, size: .zero))
        case .pen: shape = .pen([point])
        case .text: shape = .text(origin: point, string: "", fontSize: 18)
        }
        return Annotation(shape: shape, color: currentColor, lineWidth: currentWidth)
    }

    private func updateDraft(to rawPoint: CGPoint) {
        guard var draft, let start = startPoint else { return }
        let point = clampToBounds(rawPoint)
        let rect = normalizedRect(from: clampToBounds(start), to: point)
        switch draft.shape {
        case .arrow: draft.shape = .arrow(from: start, to: point)
        case .rectangle: draft.shape = .rectangle(rect)
        case .ellipse: draft.shape = .ellipse(rect)
        case .mosaic: draft.shape = .mosaic(rect)
        case .pen(var points): points.append(point); draft.shape = .pen(points)
        case .text: break
        }
        self.draft = draft
    }

    private func isValid(_ annotation: Annotation) -> Bool {
        switch annotation.shape {
        case let .rectangle(rect), let .ellipse(rect), let .mosaic(rect):
            return rect.width > 2 && rect.height > 2
        case let .arrow(from, to):
            return hypot(to.x - from.x, to.y - from.y) > 3
        case let .pen(points):
            return points.count > 1
        case let .text(_, string, _):
            return !string.isEmpty
        }
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func clampToBounds(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }

    // MARK: Text

    private func beginTextEditing(at point: CGPoint) {
        let fontSize = 12 + currentWidth * 2.5
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 220, height: fontSize + 10))
        field.font = .systemFont(ofSize: fontSize, weight: .semibold)
        field.textColor = currentColor
        field.drawsBackground = false
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "输入文字，回车确认"
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
        textOrigin = point
    }

    private func commitActiveText() {
        guard let field = activeTextField else { return }
        activeTextField = nil
        let text = field.stringValue
        let color = field.textColor ?? currentColor
        let fontSize = field.font?.pointSize ?? 18
        field.removeFromSuperview()
        guard !text.isEmpty else { return }
        annotations.append(Annotation(
            shape: .text(origin: CGPoint(x: textOrigin.x + 2, y: textOrigin.y + 3),
                         string: text, fontSize: fontSize),
            color: color,
            lineWidth: currentWidth
        ))
        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            commitActiveText()
            window?.makeFirstResponder(self)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            activeTextField?.removeFromSuperview()
            activeTextField = nil
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveText()
    }

    // MARK: Output

    private func outputImage() -> CGImage? {
        let pixelWidth = baseCGImage.width
        let pixelHeight = baseCGImage.height
        guard pixelWidth > 0, pixelHeight > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let base = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        rep.size = NSSize(width: pixelWidth, height: pixelHeight)

        NSGraphicsContext.saveGraphicsState()
        let cg = base.cgContext
        cg.translateBy(x: 0, y: CGFloat(pixelHeight))
        cg.scaleBy(x: scale, y: -scale)
        let flipped = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.current = flipped

        baseImage.draw(in: bounds)
        for annotation in annotations {
            annotation.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
        }
        NSGraphicsContext.restoreGraphicsState()

        return rep.cgImage
    }
}
