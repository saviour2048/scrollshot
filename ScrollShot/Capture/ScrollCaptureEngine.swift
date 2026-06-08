import AppKit
import CoreGraphics

/// Drives a scroll-capture session: pick a region, then grab a frame every
/// ~0.3 s while the user (manual) or the app (auto) scrolls, stitching
/// incrementally. Reports progress/results via callbacks so the UI lives in the
/// main window instead of a floating panel.
@MainActor
final class ScrollCaptureEngine {
    enum Mode { case manual, auto }
    enum Permission { case screenRecording, accessibility }

    var onCapturingStarted: (() -> Void)?
    var onProgress: ((_ height: Int, _ frames: Int, _ preview: NSImage?) -> Void)?
    var onFinished: ((_ result: CGImage?, _ savedURL: URL?) -> Void)?
    var onCancelled: (() -> Void)?
    var onPermissionNeeded: ((Permission) -> Void)?

    private let capturer = ScreenCapturer()
    private let selector = RegionSelectorController()
    private let stitcher = FrameStitcher()

    private var timer: Timer?
    private var selection: RegionSelection?
    private var mode: Mode = .manual
    private var active = false
    private var capturing = false
    private var frameInFlight = false
    private var tickCount = 0
    private var noGrowthCount = 0

    private let tickInterval: TimeInterval = 0.3
    private let autoStopAfterIdleTicks = 6
    private let maxFrames = 400

    var isActive: Bool { active }

    // MARK: Lifecycle

    func start(mode: Mode) {
        guard !active else { return }

        if !capturer.hasPermission() {
            capturer.requestPermission()
            if !capturer.hasPermission() {
                onPermissionNeeded?(.screenRecording)
                return
            }
        }
        if mode == .auto, !AutoScroller.isTrusted() {
            AutoScroller.requestTrust()
            onPermissionNeeded?(.accessibility)
            return
        }

        active = true
        self.mode = mode
        stitcher.reset()
        tickCount = 0
        noGrowthCount = 0

        selector.begin { [weak self] selection in
            guard let self else { return }
            guard let selection else { self.active = false; self.onCancelled?(); return }
            self.selection = selection
            self.beginCapturing()
        }
    }

    func finish() {
        guard active else { return }
        stopTimer()
        capturing = false
        active = false

        let result = stitcher.result()
        var savedURL: URL?
        if let result {
            ImageUtils.copyToPasteboard(result)
            savedURL = try? ImageUtils.saveToDesktop(result)
        }
        selection = nil
        onFinished?(result, savedURL)
    }

    func cancel() {
        guard active else { return }
        stopTimer()
        capturing = false
        active = false
        selection = nil
        onCancelled?()
    }

    // MARK: Capture loop

    private func beginCapturing() {
        guard let selection else { return }
        CaptureCenterWindowController.shared.repositionAvoiding(
            rect: selection.rectInScreen,
            on: selection.screen
        )
        capturing = true
        onCapturingStarted?()
        captureFrame()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard capturing else { return }
        captureFrame()
        if mode == .auto { performAutoScroll() }
    }

    private func performAutoScroll() {
        guard let selection else { return }
        let rect = selection.rectInScreen
        let step = min(max(rect.height * 0.3, 60), 300)
        AutoScroller.scrollDown(
            atAppKitPoint: CGPoint(x: rect.midX, y: rect.midY),
            pixels: Int(step)
        )
    }

    private func captureFrame() {
        guard capturing, !frameInFlight,
              let selection, let displayID = selection.screen.displayID else { return }
        frameInFlight = true

        let scale = selection.screen.backingScaleFactor
        let sourceRect = displayRelativeRect(selection)
        let excluded = CaptureCenterWindowController.shared.windowID.map { [$0] } ?? []

        Task { [weak self] in
            guard let self else { return }
            defer { self.frameInFlight = false }
            do {
                let frame = try await self.capturer.captureRegion(
                    displayID: displayID,
                    sourceRect: sourceRect,
                    scale: scale,
                    excludingWindowIDs: excluded
                )
                guard self.capturing else { return }
                let grew = self.stitcher.add(frame)
                self.tickCount += 1
                self.emitProgress()
                self.checkAutoStop(grew: grew)
            } catch {
                NSLog("ScrollShot: scroll frame capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func emitProgress() {
        let preview = (tickCount % 3 == 0) ? stitcher.result().map(ImageUtils.nsImage) : nil
        onProgress?(stitcher.totalHeight, stitcher.frameCount, preview)
    }

    /// In auto mode, stop once the page stops producing new content (bottom),
    /// or after a safety cap.
    private func checkAutoStop(grew: Bool) {
        guard mode == .auto else { return }
        if stitcher.frameCount >= maxFrames { finish(); return }
        guard stitcher.frameCount > 2 else { return }
        noGrowthCount = grew ? 0 : (noGrowthCount + 1)
        if noGrowthCount >= autoStopAfterIdleTicks { finish() }
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
}
