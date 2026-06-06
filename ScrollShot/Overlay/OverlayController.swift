import AppKit
import CoreGraphics

/// Presents one borderless, top-most window per display, each showing that
/// display's frozen screenshot. The user selects a region on one of them; the
/// completion delivers the rendered output (or nil if cancelled).
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var completion: ((CGImage?) -> Void)?

    func present(shots: [DisplayShot], completion: @escaping (CGImage?) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion

        windows = shots.map { shot in
            let window = OverlayWindow(shot: shot)
            window.canvas.onFinish = { [weak self] image in self?.finish(with: image) }
            window.canvas.onCancel = { [weak self] in self?.finish(with: nil) }
            window.orderFrontRegardless()
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func finish(with image: CGImage?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        let completion = self.completion
        self.completion = nil
        completion?(image)
    }
}

/// Borderless transparent window covering exactly one screen.
final class OverlayWindow: NSWindow {
    let canvas: OverlayCanvasView

    init(shot: DisplayShot) {
        canvas = OverlayCanvasView(shot: shot)
        super.init(
            contentRect: shot.screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setFrame(shot.screen.frame, display: true)
        contentView = canvas
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
