import AppKit
import CoreGraphics

/// Orchestrates scroll (long) capture:
/// menu → pick region → floating panel → on "开始" grab a frame every ~0.3s
/// while the user scrolls → stitch incrementally → on "结束" save the long image.
@MainActor
final class ScrollCaptureController {
    static let shared = ScrollCaptureController()

    private let capturer = ScreenCapturer()
    private let selector = RegionSelectorController()
    private let stitcher = FrameStitcher()

    private var panel: ScrollControlPanel?
    private var timer: Timer?
    private var selection: RegionSelection?

    private var busy = false
    private var capturing = false
    private var frameInFlight = false
    private var tickCount = 0

    private init() {}

    func trigger() {
        guard !busy else { return }
        busy = true
        Task { [weak self] in
            guard let self else { return }
            guard await self.ensurePermission() else { self.busy = false; return }
            self.selector.begin { [weak self] selection in
                guard let self else { return }
                guard let selection else { self.busy = false; return }
                self.beginSession(selection)
            }
        }
    }

    // MARK: Session

    private func beginSession(_ selection: RegionSelection) {
        self.selection = selection
        stitcher.reset()
        tickCount = 0

        let panel = ScrollControlPanel()
        panel.onStart = { [weak self] in self?.startCapturing() }
        panel.onFinish = { [weak self] in self?.finishCapturing() }
        panel.onCancel = { [weak self] in self?.cancelSession() }
        panel.show(near: selection.rectInScreen, on: selection.screen)
        self.panel = panel
    }

    private func startCapturing() {
        guard !capturing else { return }
        capturing = true
        panel?.setRunning(true)
        captureFrame() // grab an initial frame right away
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureFrame() }
        }
    }

    private func captureFrame() {
        guard capturing, !frameInFlight,
              let selection, let displayID = selection.screen.displayID else { return }
        frameInFlight = true

        let scale = selection.screen.backingScaleFactor
        let sourceRect = displayRelativeRect(selection)
        let exclude = panel.map { [$0.windowID] } ?? []

        Task { [weak self] in
            guard let self else { return }
            defer { self.frameInFlight = false }
            do {
                let frame = try await self.capturer.captureRegion(
                    displayID: displayID,
                    sourceRect: sourceRect,
                    scale: scale,
                    excludingWindowIDs: exclude
                )
                guard self.capturing else { return }
                self.stitcher.add(frame)
                self.tickCount += 1
                self.panel?.update(height: self.stitcher.totalHeight, frames: self.stitcher.frameCount)
                if self.tickCount % 3 == 0, let result = self.stitcher.result() {
                    self.panel?.updatePreview(ImageUtils.nsImage(from: result))
                }
            } catch {
                NSLog("ScrollShot: scroll frame capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func finishCapturing() {
        stopTimer()
        capturing = false
        let result = stitcher.result()
        teardown()

        guard let result else {
            presentInfo("没有捕获到内容。请点「开始」后再缓慢向下滚动页面。")
            return
        }
        ImageUtils.copyToPasteboard(result)
        do {
            let url = try ImageUtils.saveToDesktop(result)
            presentInfo("长截图已保存到桌面:\(url.lastPathComponent)\n尺寸 \(result.width) × \(result.height) px,已复制到剪贴板。")
        } catch {
            presentInfo("保存失败:\(error.localizedDescription)")
        }
    }

    private func cancelSession() {
        stopTimer()
        capturing = false
        teardown()
    }

    private func teardown() {
        panel?.close()
        panel = nil
        selection = nil
        busy = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func displayRelativeRect(_ selection: RegionSelection) -> CGRect {
        let frame = selection.screen.frame
        let rect = selection.rectInScreen
        return CGRect(
            x: rect.minX - frame.minX,
            y: frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: Permission / alerts

    private func ensurePermission() async -> Bool {
        if capturer.hasPermission() { return true }
        capturer.requestPermission()
        if capturer.hasPermission() { return true }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "请在 系统设置 ▸ 隐私与安全性 ▸ 屏幕录制 勾选 ScrollShot 后重新运行。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn, let url = AppConfig.screenRecordingSettingsURL {
            NSWorkspace.shared.open(url)
        }
        return false
    }

    private func presentInfo(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }
}
