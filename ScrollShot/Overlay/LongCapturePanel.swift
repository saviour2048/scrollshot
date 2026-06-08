import AppKit

/// A compact, fixed-size panel docked at the screen's bottom-left during long
/// capture: live preview, progress, an 自动滚动 button, and 完成 / 取消.
/// Excluded from the capture so it never appears in the stitched image.
///
/// Uses manual frames + a locked window size so the preview image can never
/// blow the window up to full width.
final class LongCapturePanel {
    var onAuto: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    let window: NSPanel

    private static let panelSize = NSSize(width: 220, height: 244)

    private let statusLabel = NSTextField(labelWithString: "向下滚动页面…")
    private let previewView = NSImageView()
    private let autoButton = NSButton()
    private let finishButton = NSButton()
    private let cancelButton = NSButton()

    init() {
        window = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "ScrollShot · 长截图预览"
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        // Lock the size so nothing (e.g. a wide preview image) can resize it.
        window.contentMinSize = Self.panelSize
        window.contentMaxSize = Self.panelSize
        window.setContentSize(Self.panelSize)
        buildUI()
    }

    var windowID: CGWindowID? {
        guard window.windowNumber > 0 else { return nil }
        return CGWindowID(window.windowNumber)
    }

    func show(atBottomLeftOf screen: NSScreen) {
        window.setContentSize(Self.panelSize)
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        window.setFrameOrigin(CGPoint(x: visible.minX + margin, y: visible.minY + margin))
        window.orderFrontRegardless()
    }

    func update(height: Int, frames: Int, preview: NSImage?) {
        statusLabel.stringValue = "已拼接 \(height) px · \(frames) 帧"
        if let preview { previewView.image = preview }
    }

    func setAuto(_ on: Bool) {
        autoButton.isEnabled = !on
        autoButton.title = on ? "自动滚动中…" : "自动滚动"
    }

    func note(_ text: String) {
        statusLabel.stringValue = text
    }

    func close() {
        window.orderOut(nil)
    }

    // MARK: UI (manual frames, content view is non-flipped / bottom-left origin)

    private func buildUI() {
        guard let content = window.contentView else { return }
        content.appearance = NSAppearance(named: .darkAqua)

        let pad: CGFloat = 12
        let w = Self.panelSize.width - pad * 2          // 196
        let h = Self.panelSize.height                    // 244

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.frame = NSRect(x: pad, y: h - 10 - 34, width: w, height: 34)
        content.addSubview(statusLabel)

        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageAlignment = .alignTop
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        previewView.layer?.cornerRadius = 6
        previewView.frame = NSRect(x: pad, y: 90, width: w, height: 96)
        content.addSubview(previewView)

        autoButton.title = "自动滚动"
        autoButton.bezelStyle = .rounded
        autoButton.target = self
        autoButton.action = #selector(autoTapped)
        autoButton.frame = NSRect(x: pad, y: 54, width: w, height: 28)
        content.addSubview(autoButton)

        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.frame = NSRect(x: pad, y: 16, width: (w - 8) / 2, height: 28)
        content.addSubview(cancelButton)

        finishButton.title = "完成"
        finishButton.bezelStyle = .rounded
        finishButton.bezelColor = .controlAccentColor
        finishButton.keyEquivalent = "\r"
        finishButton.target = self
        finishButton.action = #selector(finishTapped)
        finishButton.frame = NSRect(x: pad + (w - 8) / 2 + 8, y: 16, width: (w - 8) / 2, height: 28)
        content.addSubview(finishButton)
    }

    @objc private func autoTapped() { onAuto?() }
    @objc private func finishTapped() { onFinish?() }
    @objc private func cancelTapped() { onCancel?() }
}
