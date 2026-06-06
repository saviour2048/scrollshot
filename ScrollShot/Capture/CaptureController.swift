import AppKit
import CoreGraphics

/// Top-level orchestrator for the Flameshot-style flow:
/// hotkey/menu → check permission → freeze every display → show overlay →
/// save to Desktop + copy to clipboard.
@MainActor
final class CaptureController {
    static let shared = CaptureController()

    private let capturer = ScreenCapturer()
    private let overlay = OverlayController()
    private var isRunning = false

    private init() {}

    func trigger() {
        guard !isRunning else { return }
        isRunning = true
        Task { [weak self] in
            await self?.run()
            self?.isRunning = false
        }
    }

    private func run() async {
        guard await ensurePermission() else { return }

        var shots: [DisplayShot] = []
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let fullRect = CGRect(origin: .zero, size: screen.frame.size)
            do {
                let image = try await capturer.captureRegion(
                    displayID: displayID,
                    sourceRect: fullRect,
                    scale: screen.backingScaleFactor
                )
                shots.append(DisplayShot(screen: screen, image: image))
            } catch {
                NSLog("ScrollShot: failed to capture display \(displayID): \(error.localizedDescription)")
            }
        }

        guard !shots.isEmpty else { return }
        overlay.present(shots: shots) { [weak self] result in
            self?.finish(with: result)
        }
    }

    private func finish(with result: CGImage?) {
        guard let image = result else { return }
        ImageUtils.copyToPasteboard(image)
        do {
            let url = try ImageUtils.saveToDesktop(image)
            NSLog("ScrollShot: saved \(url.path)")
        } catch {
            presentError("保存到桌面失败：\(error.localizedDescription)")
        }
    }

    // MARK: Permission

    private func ensurePermission() async -> Bool {
        if capturer.hasPermission() { return true }
        capturer.requestPermission()
        if capturer.hasPermission() { return true }
        presentPermissionAlert()
        return false
    }

    private func presentPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "请在 系统设置 ▸ 隐私与安全性 ▸ 屏幕录制 勾选 ScrollShot，然后重新运行 App。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn, let url = AppConfig.screenRecordingSettingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func presentError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

/// A single display's frozen screenshot plus the screen it belongs to.
struct DisplayShot {
    let screen: NSScreen
    let image: CGImage
}
