import AppKit

/// Hosts the long-screenshot editor window: the shared annotation toolbar on
/// top and a scrollable editable canvas below. Reuses `AnnotationBar` and
/// `AnnotationEditorView` so editing a long image works exactly like the
/// screenshot flow.
@MainActor
final class AnnotationEditorWindowController {
    static let shared = AnnotationEditorWindowController()

    private var window: NSWindow?

    private init() {}

    func open(image: CGImage, scale: CGFloat) {
        window?.close()

        let editor = AnnotationEditorView(image: image, scale: scale)
        let bar = AnnotationBar(showsLongCapture: false)
        editor.setColor(bar.currentColor)
        editor.setWidth(bar.currentWidth)

        bar.onSelectTool = { [weak editor] tool in editor?.selectTool(tool) }
        bar.onColor = { [weak editor] color in editor?.setColor(color) }
        bar.onWidth = { [weak editor] width in editor?.setWidth(width) }
        bar.onUndo = { [weak editor] in editor?.undo() }
        bar.onCopy = { [weak editor] in editor?.copy() }
        bar.onSave = { [weak self, weak editor] in
            editor?.save()
            self?.close()
        }
        bar.onCancel = { [weak self] in self?.close() }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = editor
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let barSize = bar.contentSize
        bar.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(bar)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            bar.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bar.widthAnchor.constraint(equalToConstant: barSize.width),
            bar.heightAnchor.constraint(equalToConstant: barSize.height),
            scrollView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let displayWidth = CGFloat(image.width) / max(1, scale)
        let displayHeight = CGFloat(image.height) / max(1, scale)
        // Keep the editor compact (it scrolls); never a huge full-width bar.
        let contentWidth = min(max(displayWidth, barSize.width) + 40, 540)
        let contentHeight = max(420, min(displayHeight + barSize.height + 40, 760))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "长截图 — 编辑后保存到桌面"
        window.contentView = container
        window.isReleasedWhenClosed = false
        // Dock to the bottom-left rather than dominating the screen.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(CGPoint(x: visible.minX + 24, y: visible.minY + 24))
        } else {
            window.center()
        }
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
        window = nil
    }
}
