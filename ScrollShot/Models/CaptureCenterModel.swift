import AppKit
import Combine

/// State + actions for the 截图中心 window, bridging the SwiftUI UI and the
/// capture controllers.
@MainActor
final class CaptureCenterModel: ObservableObject {
    static let shared = CaptureCenterModel()

    enum Phase {
        case idle        // configuring; nothing running
        case capturing   // a scroll session is in progress
        case finished    // a result is ready
    }

    /// false = manual wheel scrolling (default), true = app auto-scrolls.
    @Published var autoScroll = false
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var preview: NSImage?
    @Published private(set) var height = 0
    @Published private(set) var frames = 0
    @Published private(set) var message = ""

    private let engine = ScrollCaptureEngine()

    private init() {
        engine.onCapturingStarted = { [weak self] in
            self?.phase = .capturing
            self?.message = ""
        }
        engine.onProgress = { [weak self] height, frames, preview in
            self?.height = height
            self?.frames = frames
            if let preview { self?.preview = preview }
        }
        engine.onFinished = { [weak self] result, savedURL in
            guard let self else { return }
            if let result {
                self.preview = ImageUtils.nsImage(from: result)
                self.phase = .finished
                self.message = savedURL.map { "已保存到桌面:\($0.lastPathComponent),并已复制到剪贴板。" }
                    ?? "已生成长图,但保存失败。"
            } else {
                self.phase = .idle
                self.message = "没有捕获到内容。请点开始后向下滚动页面。"
            }
        }
        engine.onCancelled = { [weak self] in self?.resetState() }
        engine.onPermissionNeeded = { [weak self] permission in
            self?.handlePermission(permission)
        }
    }

    var isCapturing: Bool { phase == .capturing }

    // MARK: Actions

    /// Normal (Flameshot-style) frozen capture. Hide this window first so it
    /// isn't part of the frozen screenshot.
    func normalCapture() {
        CaptureCenterWindowController.shared.hide()
        CaptureController.shared.trigger()
    }

    func startScroll() {
        resetState()
        engine.start(mode: autoScroll ? .auto : .manual)
    }

    func finishScroll() {
        engine.finish()
    }

    func cancelScroll() {
        engine.cancel()
    }

    func startOver() {
        resetState()
    }

    // MARK: Helpers

    private func resetState() {
        phase = .idle
        preview = nil
        height = 0
        frames = 0
        message = ""
    }

    private func handlePermission(_ permission: ScrollCaptureEngine.Permission) {
        switch permission {
        case .screenRecording:
            message = "需要「屏幕录制」权限。请在 系统设置▸隐私与安全性▸屏幕录制 勾选 ScrollShot 后重新运行。"
            if let url = AppConfig.screenRecordingSettingsURL { NSWorkspace.shared.open(url) }
        case .accessibility:
            message = "自动滚动需要「辅助功能」权限。请在弹出的系统设置里勾选 ScrollShot,然后再点一次开始。"
        }
    }
}
