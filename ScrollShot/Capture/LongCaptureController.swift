import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Runs a long (scroll) capture for an already-chosen region: shows the
/// bottom-left panel, grabs a frame every ~0.3 s while the user (manual) or the
/// app (auto) scrolls, stitches incrementally, and on 完成 opens the stitched
/// long image in the annotation editor.
@MainActor
final class LongCaptureController {
    static let shared = LongCaptureController()

    private let capturer = ScreenCapturer()
    private let stitcher = FrameStitcher()
    /// All `stitcher` access (add / result) happens here, off the main thread.
    private let stitchQueue = DispatchQueue(label: "com.scrollshot.stitch")

    private var panel: LongCapturePanel?
    private var timer: Timer?
    private var region: LongCaptureRegion?
    private var filter: SCContentFilter?   // built once per session (avoids per-frame system query)

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
        let stitcher = self.stitcher
        stitchQueue.async { stitcher.reset() }   // serialized before any add
        tickCount = 0
        noGrowthCount = 0

        let panel = LongCapturePanel()
        panel.onAuto = { [weak self] in self?.enableAuto() }
        panel.onFinish = { [weak self] in self?.finish() }
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.show(atBottomLeftOf: region.screen)
        self.panel = panel

        // Build the capture filter ONCE (excluding the panel), then start ticking.
        let excluded = panel.windowID.map { [$0] } ?? []
        Task { [weak self] in
            guard let self else { return }
            do {
                self.filter = try await self.capturer.makeFilter(
                    displayID: region.displayID,
                    excludingWindowIDs: excluded
                )
            } catch {
                NSLog("ScrollShot: makeFilter failed: \(error.localizedDescription)")
            }
            guard self.active else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.tickInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    // MARK: Scrolling

    private func enableAuto() {
        guard active else { return }
        if !AutoScroller.isTrusted() {
            AutoScroller.requestTrust()
            panel?.note("需要「辅助功能」权限:系统设置▸隐私与安全性▸辅助功能 勾选 ScrollShot,然后再点「自动滚动」。")
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        auto = true
        noGrowthCount = 0
        panel?.setAuto(true)
        panel?.note("自动滚动中…到底会自动停止。")
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
        guard active, !frameInFlight, let region, let filter else { return }
        frameInFlight = true
        let stitcher = self.stitcher
        let sourceRect = region.sourceRect
        let scale = region.scale
        let isAuto = auto
        let showPreview = (tickCount % 2 == 0)
        tickCount += 1

        Task { [weak self] in
            guard let self else { return }
            do {
                let frame = try await self.capturer.capture(filter: filter, sourceRect: sourceRect, scale: scale)
                // Stitch off the main thread so scrolling / UI stays smooth.
                self.stitchQueue.async {
                    let grew = stitcher.add(frame)
                    let height = stitcher.totalHeight
                    let frames = stitcher.frameCount
                    let preview = showPreview ? ImageUtils.nsImage(from: frame) : nil
                    Task { @MainActor in
                        self.frameInFlight = false
                        guard self.active else { return }
                        self.panel?.update(height: height, frames: frames, preview: preview)
                        if isAuto { self.checkAutoStop(grew: grew, frames: frames) }
                    }
                }
            } catch {
                NSLog("ScrollShot: long capture frame failed: \(error.localizedDescription)")
                self.frameInFlight = false
            }
        }
    }

    private func checkAutoStop(grew: Bool, frames: Int) {
        if frames >= maxFrames { finish(); return }
        guard frames > 2 else { return }
        noGrowthCount = grew ? 0 : (noGrowthCount + 1)
        if noGrowthCount >= autoStopIdleTicks { finish() }
    }

    // MARK: Finish / cancel

    private func finish() {
        guard active else { return }
        stopTimer()
        active = false
        let scale = region?.scale ?? 2
        let stitcher = self.stitcher
        panel?.close()
        panel = nil
        region = nil
        filter = nil

        // Compose on the stitch queue so any in-flight `add`s finish first.
        stitchQueue.async {
            let result = stitcher.result()
            Task { @MainActor in
                guard let result else {
                    self.presentInfo("没有捕获到内容。请重试,记得向下滚动页面。")
                    return
                }
                AnnotationEditorWindowController.shared.open(image: result, scale: scale)
            }
        }
    }

    private func cancel() {
        guard active else { return }
        stopTimer()
        active = false
        panel?.close()
        panel = nil
        region = nil
        filter = nil
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
