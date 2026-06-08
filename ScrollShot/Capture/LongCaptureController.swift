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
    private var didWarpCursor = false
    private var frameInFlight = false
    private var tickCount = 0
    private var noGrowthCount = 0
    private var escMonitorLocal: Any?
    private var escMonitorGlobal: Any?

    private let tickInterval: TimeInterval = 0.3
    private let autoStopIdleTicks = 6
    private let maxFrames = 500

    private init() {}

    func begin(region: LongCaptureRegion) {
        guard !active else { return }
        active = true
        auto = false
        didWarpCursor = false
        self.region = region
        let stitcher = self.stitcher
        stitchQueue.async { stitcher.reset() }   // serialized before any add
        tickCount = 0
        noGrowthCount = 0
        installEscapeHatch()

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
        // Don't gate on AXIsProcessTrusted() — it often false-reports "not trusted"
        // for Xcode-run apps. Just try to scroll; if Accessibility is actually
        // granted the events work, otherwise the first post triggers the system
        // prompt. Show a hint either way.
        auto = true
        didWarpCursor = false
        noGrowthCount = 0
        panel?.setAuto(true)
        panel?.note("自动滚动中…按 Esc 或把鼠标移出选区即可停下,再点「完成/取消」。")
    }

    private func tick() {
        guard active else { return }
        captureFrame()
        if auto { performAutoScroll() }
    }

    private func performAutoScroll() {
        guard let region else { return }
        // Position the cursor over the region ONCE, then never grab it again —
        // so the user keeps control of the mouse and can click 完成/取消.
        if !didWarpCursor {
            AutoScroller.warp(toAppKitPoint: CGPoint(x: region.globalRect.midX, y: region.globalRect.midY))
            didWarpCursor = true
            return
        }
        // Only scroll while the cursor is still over the region. Moving the mouse
        // out (e.g. toward the panel) pauses auto-scroll — an easy escape.
        guard region.globalRect.contains(NSEvent.mouseLocation) else { return }
        let step = min(max(region.globalRect.height * 0.3, 60), 300)
        AutoScroller.postScrollDown(pixels: Int(step))
    }

    // MARK: Escape hatch

    private func installEscapeHatch() {
        // Esc cancels the session, whether ScrollShot or the scrolled app is active.
        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel(); return nil }
            return event
        }
        escMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.cancel() }
        }
    }

    private func removeEscapeHatch() {
        [escMonitorLocal, escMonitorGlobal].forEach { if let m = $0 { NSEvent.removeMonitor(m) } }
        escMonitorLocal = nil
        escMonitorGlobal = nil
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
        removeEscapeHatch()
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
        removeEscapeHatch()
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
