import AppKit
import SwiftUI

/// Hosts the main "截图中心" window (SwiftUI content in an AppKit window so we
/// can read its window id — to exclude it from scroll captures — and reposition
/// it out of the captured region).
@MainActor
final class CaptureCenterWindowController {
    static let shared = CaptureCenterWindowController()

    private var window: NSWindow?

    private init() {}

    /// The window's CoreGraphics id, used to exclude it from capture.
    var windowID: CGWindowID? {
        guard let number = window?.windowNumber, number > 0 else { return nil }
        return CGWindowID(number)
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: CaptureCenterView(model: .shared))
            let window = NSWindow(contentViewController: hosting)
            window.title = "ScrollShot 截图中心"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 440, height: 600))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    /// Moves the window to whichever side of the region has more room, so it
    /// neither covers the content being scrolled nor appears in the capture.
    func repositionAvoiding(rect: CGRect, on screen: NSScreen) {
        guard let window else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let spaceRight = visible.maxX - rect.maxX
        let spaceLeft = rect.minX - visible.minX

        var origin = CGPoint(x: visible.minX + 16, y: visible.midY - size.height / 2)
        if spaceRight >= spaceLeft {
            origin.x = min(visible.maxX - size.width - 16, rect.maxX + 16)
        } else {
            origin.x = max(visible.minX + 16, rect.minX - size.width - 16)
        }
        origin.y = min(max(visible.minY + 16, origin.y), visible.maxY - size.height - 16)
        window.setFrameOrigin(origin)
    }
}
