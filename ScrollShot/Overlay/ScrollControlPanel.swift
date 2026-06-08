import AppKit

/// Small floating panel shown beside the scroll-capture region: a start/stop
/// button, a live status line, and a shrinking preview of the stitched result.
/// The panel window is excluded from capture so it never appears in the output.
final class ScrollControlPanel {
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    let window: NSPanel

    private let statusLabel = NSTextField(labelWithString: "")
    private let previewView = NSImageView()
    private let primaryButton = NSButton()
    private let cancelButton = NSButton()
    private var isRunning = false

    init() {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 240),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "滚动截图"
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.worksWhenModal = true
        buildUI()
        setRunning(false)
    }

    var windowID: CGWindowID { CGWindowID(window.windowNumber) }

    func show(near rect: CGRect, on screen: NSScreen) {
        // `rect` is in global AppKit (bottom-left) coordinates. Prefer placing the
        // panel to the right of the region; fall back to the left / below.
        let size = window.frame.size
        let margin: CGFloat = 12
        var origin = CGPoint(x: rect.maxX + margin, y: rect.maxY - size.height)

        let visible = screen.visibleFrame
        if origin.x + size.width > visible.maxX {
            origin.x = rect.minX - size.width - margin          // left of the region
        }
        if origin.x < visible.minX {
            origin.x = rect.minX                                 // give up: overlap edge
            origin.y = rect.minY - size.height - margin          // below the region
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)

        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
    }

    func close() {
        window.orderOut(nil)
    }

    func setRunning(_ running: Bool) {
        isRunning = running
        primaryButton.title = running ? "结束并保存" : "开始"
        primaryButton.keyEquivalent = running ? "" : "\r"
        statusLabel.stringValue = running ? "正在捕获…请缓慢向下滚动页面" : "点「开始」后向下滚动页面"
    }

    func update(height: Int, frames: Int) {
        guard isRunning else { return }
        statusLabel.stringValue = "已拼接 \(height) px ·  \(frames) 帧 — 滚到底后点「结束并保存」"
    }

    func updatePreview(_ image: NSImage?) {
        previewView.image = image
    }

    // MARK: UI

    private func buildUI() {
        guard let content = window.contentView else { return }

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.imageAlignment = .alignTop
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        previewView.layer?.cornerRadius = 6
        previewView.layer?.borderWidth = 1
        previewView.layer?.borderColor = NSColor.separatorColor.cgColor

        primaryButton.bezelStyle = .rounded
        primaryButton.target = self
        primaryButton.action = #selector(primaryTapped)

        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)

        let buttons = NSStackView(views: [cancelButton, primaryButton])
        buttons.orientation = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 8

        let stack = NSStackView(views: [statusLabel, previewView, buttons])
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
            previewView.heightAnchor.constraint(equalToConstant: 130),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24)
        ])
    }

    @objc private func primaryTapped() {
        if isRunning { onFinish?() } else { onStart?() }
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
