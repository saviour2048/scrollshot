import AppKit
import CoreGraphics

/// What the frozen overlay produced.
enum OverlayResult {
    case image(CGImage)              // normal screenshot, ready to save
    case longCapture(LongCaptureRegion)  // user chose 长截图 for this region
    case cancelled
}

/// Presents one borderless, top-most window per display, each showing that
/// display's frozen screenshot. The user selects a region on one of them; the
/// completion delivers the result.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var completion: ((OverlayResult) -> Void)?

    func present(shots: [DisplayShot], completion: @escaping (OverlayResult) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion

        windows = shots.map { shot in
            let window = OverlayWindow(shot: shot)
            window.canvas.onFinish = { [weak self] image in self?.finish(.image(image)) }
            window.canvas.onCancel = { [weak self] in self?.finish(.cancelled) }
            window.canvas.onLongCapture = { [weak self] region in self?.finish(.longCapture(region)) }
            window.orderFrontRegardless()
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func finish(_ result: OverlayResult) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        let completion = self.completion
        self.completion = nil
        completion?(result)
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
