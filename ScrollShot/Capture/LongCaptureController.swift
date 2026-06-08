import AppKit
import CoreGraphics

/// Runs a long (scroll) capture for an already-chosen region: shows the
/// bottom-left panel, grabs a frame every ~0.3 s while the user (manual) or the
/// app (auto) scrolls, stitches incrementally, and on 完成 opens the stitched
/// long image in the annotation editor.
@MainActor
final class LongCaptureController {
    static let shared = LongCaptureController()

    private let capturer = ScreenCapturer()
    private let stitcher = FrameStitcher()

    private var panel: LongCapturePanel?
    private var timer: Timer?
    private var region: LongCaptureRegion?

    private var active = false
    private var auto = false
    private var frameInFlight = false
    private var tickCount = 0
    private var noGrowthCount = 0

    private let tickInterval: TimeInterval = 0.3
    private let autoStopIdleTicks = 6
    private let maxFrames = 500

    private init() {}

    func begin(region: LongCaptureRegion) {
        guard !active else { return }
        active = true
        auto = false
        self.region = region
        stitcher.reset()
        tickCount = 0
        noGrowthCount = 0

        let panel = LongCapturePanel()
        panel.onAuto = { [weak self] in self?.enableAuto() }
        panel.onFinish = { [weak self] in self?.finish() }
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.show(atBottomLeftOf: region.screen)
        self.panel = panel

        captureFrame()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // MARK: Scrolling

    private func enableAuto() {
        guard active else { return }
        if !AutoScroller.isTrusted() {
            AutoScroller.requestTrust()
            panel?.note("需要「辅助功能」权限。请在系统设置勾选 ScrollShot 后再点「自动滚动」。")
            return
        }
        auto = true
        noGrowthCount = 0
        panel?.setAuto(true)
    }

    private func tick() {
        guard active else { return }
        captureFrame()
        if auto { performAutoScroll() }
    }

    private func performAutoScroll() {
        guard let region else { return }
        let step = min(max(region.globalRect.height * 0.3, 60), 300)
        AutoScroller.scrollDown(
            atAppKitPoint: CGPoint(x: region.globalRect.midX, y: region.globalRect.midY),
            pixels: Int(step)
        )
    }

    // MARK: Capture

    private func captureFrame() {
        guard active, !frameInFlight, let region else { return }
        frameInFlight = true
        let excluded = panel?.windowID.map { [$0] } ?? []

        Task { [weak self] in
            guard let self else { return }
            defer { self.frameInFlight = false }
            do {
                let frame = try await self.capturer.captureRegion(
                    displayID: region.displayID,
                    sourceRect: region.sourceRect,
                    scale: region.scale,
                    excludingWindowIDs: excluded
                )
                guard self.active else { return }
                let grew = self.stitcher.add(frame)
                self.tickCount += 1
                // Cheap live preview: show the latest frame, NOT the full growing
                // stitch (composing it every tick was the source of the lag).
                let preview = (self.tickCount % 2 == 0) ? ImageUtils.nsImage(from: frame) : nil
                self.panel?.update(height: self.stitcher.totalHeight, frames: self.stitcher.frameCount, preview: preview)
                if self.auto { self.checkAutoStop(grew: grew) }
            } catch {
                NSLog("ScrollShot: long capture frame failed: \(error.localizedDescription)")
            }
        }
    }

    private func checkAutoStop(grew: Bool) {
        if stitcher.frameCount >= maxFrames { finish(); return }
        guard stitcher.frameCount > 2 else { return }
        noGrowthCount = grew ? 0 : (noGrowthCount + 1)
        if noGrowthCount >= autoStopIdleTicks { finish() }
    }

    // MARK: Finish / cancel

    private func finish() {
        guard active else { return }
        stopTimer()
        active = false
        let scale = region?.scale ?? 2
        let result = stitcher.result()
        panel?.close()
        panel = nil
        region = nil

        guard let result else {
            presentInfo("没有捕获到内容。请重试,记得向下滚动页面。")
            return
        }
        AnnotationEditorWindowController.shared.open(image: result, scale: scale)
    }

    private func cancel() {
        guard active else { return }
        stopTimer()
        active = false
        panel?.close()
        panel = nil
        region = nil
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func presentInfo(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }
}
