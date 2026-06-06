import AppKit
import CoreGraphics

/// The interactive surface for one display: draws the frozen screenshot, dims
/// everything outside the dragged selection, and shows an action bar once a
/// region is chosen. Output is produced by cropping the frozen image to the
/// selection (the selection *is* the crop, Flameshot-style).
///
/// Coordinate space: the view is flipped (top-left origin), so selection points
/// map directly to the frozen image's pixels via `* backingScaleFactor`.
final class OverlayCanvasView: NSView {
    var onFinish: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    private let shot: DisplayShot
    private let frozenImage: NSImage

    private var startPoint: CGPoint?
    private var selectionRect: CGRect? { didSet { needsDisplay = true } }
    private var actionBar: NSView?

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

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        // 1. Frozen screenshot at full brightness.
        frozenImage.draw(in: bounds)
        // 2. Dim the whole surface.
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        guard let rect = selectionRect, rect.width > 0, rect.height > 0 else {
            drawHint()
            return
        }

        // 3. Redraw the selection region at full brightness by clipping to it.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        frozenImage.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        border.stroke()

        drawSizeLabel(for: rect)
    }

    private func drawHint() {
        let text = "拖动选择截图区域 · Esc 取消" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height * 0.4)
        text.draw(at: origin, withAttributes: attributes)
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
        let background = CGRect(
            x: origin.x - padding / 2,
            y: origin.y - padding / 2,
            width: size.width + padding,
            height: size.height + padding
        )
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attributes)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        removeActionBar()
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        ).intersection(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        guard let rect = selectionRect,
              rect.width >= AppConfig.minimumSelectionSize,
              rect.height >= AppConfig.minimumSelectionSize else {
            selectionRect = nil
            return
        }
        showActionBar(for: rect)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Esc
            onCancel?()
        case 36, 76: // Return / Enter
            confirm()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: Action bar

    private func showActionBar(for rect: CGRect) {
        removeActionBar()

        let save = makeButton(title: "保存", action: #selector(handleSave))
        let copy = makeButton(title: "复制", action: #selector(handleCopy))
        let cancel = makeButton(title: "取消", action: #selector(handleCancel))

        let stack = NSStackView(views: [save, copy, cancel])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        addSubview(container)
        container.layoutSubtreeIfNeeded()
        let barSize = container.fittingSize

        let gap: CGFloat = 8
        var origin = CGPoint(x: rect.minX, y: rect.maxY + gap)
        if origin.y + barSize.height > bounds.height {
            origin.y = rect.minY - gap - barSize.height
        }
        if origin.y < 0 {
            origin.y = max(0, rect.maxY - barSize.height - gap)
        }
        origin.x = min(max(0, origin.x), bounds.width - barSize.width)
        container.frame = CGRect(origin: origin, size: barSize)

        actionBar = container
    }

    private func removeActionBar() {
        actionBar?.removeFromSuperview()
        actionBar = nil
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.contentTintColor = .white
        return button
    }

    @objc private func handleSave() { confirm() }

    @objc private func handleCopy() {
        guard let image = outputImage() else { onCancel?(); return }
        ImageUtils.copyToPasteboard(image)
        onCancel?() // dismiss without re-saving; CaptureController only saves on finish
    }

    @objc private func handleCancel() { onCancel?() }

    private func confirm() {
        guard let image = outputImage() else { onCancel?(); return }
        onFinish?(image)
    }

    // MARK: Output

    private func outputImage() -> CGImage? {
        guard let rect = selectionRect, rect.width >= 1, rect.height >= 1 else { return nil }
        let scale = shot.screen.backingScaleFactor
        let pixelRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
        return shot.image.cropping(to: pixelRect)
    }
}
