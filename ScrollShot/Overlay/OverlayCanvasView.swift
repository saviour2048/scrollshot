import AppKit
import CoreGraphics

/// The interactive surface for one display: frozen screenshot, dimmed outside
/// the selection, an annotation toolbar, and the drawing tools themselves.
/// Output is the selection region of the frozen image composited with all
/// annotations, at full pixel resolution.
///
/// Coordinate space: the view is flipped (top-left origin), so selection &
/// annotation points map directly to frozen-image pixels via `* backingScaleFactor`.
final class OverlayCanvasView: NSView, NSTextFieldDelegate {
    var onFinish: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    private enum Mode { case idle, selecting, drawing }

    private let shot: DisplayShot
    private let frozenImage: NSImage

    private var mode: Mode = .idle
    private var startPoint: CGPoint?
    private var selectionRect: CGRect? { didSet { needsDisplay = true } }

    private var annotations: [Annotation] = []
    private var draft: Annotation?
    private var currentTool: AnnotationTool?
    private var currentColor: NSColor = .systemRed
    private var currentWidth: CGFloat = 4

    private var bar: AnnotationBar?
    private var activeTextField: NSTextField?
    private var textOrigin: CGPoint = .zero

    private lazy var pixelatedImage: NSImage? = {
        guard let cg = ImageUtils.pixelated(shot.image) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }()

    init(shot: DisplayShot) {
        self.shot = shot
        self.frozenImage = NSImage(
            cgImage: shot.image,
            size: NSSize(width: shot.image.width, height: shot.image.height)
        )
        super.init(frame: NSRect(origin: .zero, size: shot.screen.frame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var scale: CGFloat { shot.screen.backingScaleFactor }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        frozenImage.draw(in: bounds)
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        guard let rect = selectionRect, rect.width > 0, rect.height > 0 else {
            drawHint()
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        frozenImage.draw(in: bounds)
        drawAnnotations()
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        border.stroke()

        drawSizeLabel(for: rect)
    }

    private func drawAnnotations() {
        for annotation in annotations {
            annotation.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
        }
        draft?.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
    }

    private func drawHint() {
        let text = "拖动选择截图区域 · Esc 取消" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height * 0.4),
                  withAttributes: attributes)
    }

    private func drawSizeLabel(for rect: CGRect) {
        let label = "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded()))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = label.size(withAttributes: attributes)
        let padding: CGFloat = 6
        var origin = CGPoint(x: rect.minX, y: rect.minY - size.height - padding)
        if origin.y < 0 { origin.y = rect.minY + padding }
        let background = CGRect(x: origin.x - padding / 2, y: origin.y - padding / 2,
                               width: size.width + padding, height: size.height + padding)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attributes)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        commitActiveText()
        let point = convert(event.locationInWindow, from: nil)

        guard let selection = selectionRect else {
            beginSelection(at: point)
            return
        }

        if selection.contains(point), let tool = currentTool {
            if tool == .text {
                beginTextEditing(at: point)
            } else {
                beginDrawing(tool: tool, at: point)
            }
        } else {
            annotations.removeAll()
            draft = nil
            beginSelection(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch mode {
        case .selecting:
            selectionRect = normalizedRect(from: start, to: point).intersection(bounds)
        case .drawing:
            updateDraft(from: start, to: point)
            needsDisplay = true
        case .idle:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil; mode = .idle }
        switch mode {
        case .selecting:
            if let rect = selectionRect,
               rect.width >= AppConfig.minimumSelectionSize,
               rect.height >= AppConfig.minimumSelectionSize {
                showBar(for: rect)
            } else {
                selectionRect = nil
            }
        case .drawing:
            if let draft, isValid(draft) { annotations.append(draft) }
            draft = nil
            needsDisplay = true
        case .idle:
            break
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel?()           // Esc
        case 36, 76: confirmSave()     // Return / Enter
        default: super.keyDown(with: event)
        }
    }

    // MARK: Selection / drawing helpers

    private func beginSelection(at point: CGPoint) {
        mode = .selecting
        startPoint = point
        selectionRect = nil
        bar?.isHidden = true
    }

    private func beginDrawing(tool: AnnotationTool, at point: CGPoint) {
        mode = .drawing
        startPoint = point
        draft = initialDraft(tool: tool, at: point)
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

    private func updateDraft(from start: CGPoint, to rawPoint: CGPoint) {
        guard var draft, let selection = selectionRect else { return }
        let point = clamp(rawPoint, to: selection)
        let rect = normalizedRect(from: clamp(start, to: selection), to: point)
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

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                y: min(max(point.y, rect.minY), rect.maxY))
    }

    // MARK: Text annotations

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
        field.cell?.wraps = false
        field.cell?.isScrollable = true
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
        let origin = CGPoint(x: textOrigin.x + 2, y: textOrigin.y + 3)
        annotations.append(Annotation(
            shape: .text(origin: origin, string: text, fontSize: fontSize),
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

    // MARK: Toolbar

    private func showBar(for rect: CGRect) {
        let bar = self.bar ?? makeBar()
        bar.isHidden = false
        positionBar(bar, for: rect)
    }

    private func makeBar() -> AnnotationBar {
        let bar = AnnotationBar()
        bar.onSelectTool = { [weak self] tool in self?.currentTool = tool }
        bar.onColor = { [weak self] color in self?.currentColor = color }
        bar.onWidth = { [weak self] width in self?.currentWidth = width }
        bar.onUndo = { [weak self] in self?.undo() }
        bar.onSave = { [weak self] in self?.confirmSave() }
        bar.onCopy = { [weak self] in self?.confirmCopy() }
        bar.onCancel = { [weak self] in self?.onCancel?() }
        currentColor = bar.currentColor
        currentWidth = bar.currentWidth
        addSubview(bar)
        self.bar = bar
        return bar
    }

    private func positionBar(_ bar: AnnotationBar, for rect: CGRect) {
        bar.layoutSubtreeIfNeeded()
        let size = bar.fittingSize
        let gap: CGFloat = 8
        var origin = CGPoint(x: rect.minX, y: rect.maxY + gap)
        if origin.y + size.height > bounds.height {
            origin.y = rect.minY - gap - size.height
        }
        if origin.y < 0 {
            origin.y = max(0, min(bounds.height - size.height, rect.maxY + gap))
        }
        origin.x = min(max(0, origin.x), max(0, bounds.width - size.width))
        bar.frame = CGRect(origin: origin, size: size)
    }

    private func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        needsDisplay = true
    }

    // MARK: Output

    private func confirmSave() {
        commitActiveText()
        guard let image = outputImage() else { onCancel?(); return }
        onFinish?(image)
    }

    private func confirmCopy() {
        commitActiveText()
        guard let image = outputImage() else { onCancel?(); return }
        ImageUtils.copyToPasteboard(image)
        onCancel?()
    }

    /// Renders the frozen image + annotations at full pixel resolution, then
    /// crops to the selection.
    private func outputImage() -> CGImage? {
        guard let rect = selectionRect, rect.width >= 1, rect.height >= 1 else { return nil }

        let pixelWidth = Int((bounds.width * scale).rounded())
        let pixelHeight = Int((bounds.height * scale).rounded())
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
        // Keep user space in pixels (1 unit = 1 px) to avoid points/pixels ambiguity.
        rep.size = NSSize(width: pixelWidth, height: pixelHeight)

        NSGraphicsContext.saveGraphicsState()
        let cg = base.cgContext
        // Establish a top-left, point-unit coordinate system…
        cg.translateBy(x: 0, y: CGFloat(pixelHeight))
        cg.scaleBy(x: scale, y: -scale)
        // …and present it as a *flipped* context so NSImage/NSBezierPath render
        // upright exactly like the live (flipped) view.
        let flipped = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.current = flipped

        frozenImage.draw(in: bounds)
        for annotation in annotations {
            annotation.draw(pixelatedImage: pixelatedImage, fullBounds: bounds)
        }
        NSGraphicsContext.restoreGraphicsState()

        guard let full = rep.cgImage else { return nil }
        let pixelRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
        return full.cropping(to: pixelRect)
    }
}
