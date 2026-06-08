import AppKit

/// A compact panel docked at the screen's bottom-left during long capture:
/// live preview, progress, an 自动滚动 button, and 完成 / 取消. Excluded from
/// the capture so it never appears in the stitched image.
final class LongCapturePanel {
    var onAuto: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    let window: NSPanel

    private let statusLabel = NSTextField(labelWithString: "向下滚动页面…")
    private let previewView = NSImageView()
    private let autoButton = NSButton()

    init() {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 210),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "ScrollShot · 长截图预览"
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        buildUI()
    }

    var windowID: CGWindowID? {
        guard window.windowNumber > 0 else { return nil }
        return CGWindowID(window.windowNumber)
    }

    func show(atBottomLeftOf screen: NSScreen) {
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

    private func buildUI() {
        guard let content = window.contentView else { return }
        content.appearance = NSAppearance(named: .darkAqua)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping

        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageAlignment = .alignTop
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        previewView.layer?.cornerRadius = 6

        autoButton.title = "自动滚动"
        autoButton.bezelStyle = .rounded
        autoButton.target = self
        autoButton.action = #selector(autoTapped)

        let finishButton = NSButton(title: "完成", target: self, action: #selector(finishTapped))
        finishButton.bezelStyle = .rounded
        finishButton.bezelColor = .controlAccentColor
        finishButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded

        let actionRow = NSStackView(views: [cancelButton, finishButton])
        actionRow.orientation = .horizontal
        actionRow.distribution = .fillEqually
        actionRow.spacing = 8

        let stack = NSStackView(views: [statusLabel, previewView, autoButton, actionRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            previewView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            previewView.heightAnchor.constraint(equalToConstant: 90),
            autoButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            actionRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24)
        ])
    }

    @objc private func autoTapped() { onAuto?() }
    @objc private func finishTapped() { onFinish?() }
    @objc private func cancelTapped() { onCancel?() }
}
