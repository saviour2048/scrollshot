import AppKit
import CoreGraphics
import ApplicationServices

/// Posts scroll-wheel events to auto-scroll the content under a point.
/// Requires the Accessibility ("辅助功能") permission to post events.
enum AutoScroller {
    /// Whether the app is currently trusted to post events.
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility access (shows the system dialog).
    static func requestTrust() {
        // Use the raw key string to avoid SDK differences in how
        // `kAXTrustedCheckOptionPrompt` is imported into Swift.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Scrolls down at an AppKit-global point by `pixels` (positive = downward,
    /// i.e. revealing content further down the page).
    static func scrollDown(atAppKitPoint appKitPoint: CGPoint, pixels: Int) {
        let target = cgPoint(fromAppKit: appKitPoint)
        CGWarpMouseCursorPosition(target)
        // Negative wheel1 scrolls the page content downward. If a particular setup
        // scrolls the wrong way, flip the sign here.
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(-pixels),
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.location = target
        event.post(tap: .cghidEventTap)
    }

    /// Converts an AppKit-global point (bottom-left origin) to a CoreGraphics
    /// global point (top-left origin), used by the cursor / event APIs.
    private static func cgPoint(fromAppKit point: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
