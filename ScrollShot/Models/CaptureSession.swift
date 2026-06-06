import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Observable state for the M1 flow: permission, region selection and a single
/// captured frame plus its export actions.
@MainActor
final class CaptureSession: ObservableObject {

    enum PermissionState: Equatable {
        case unknown
        case authorized
        case denied
    }

    @Published private(set) var permission: PermissionState = .unknown
    @Published private(set) var selection: RegionSelection?
    @Published private(set) var capturedImage: NSImage?
    @Published private(set) var isBusy = false
    @Published var statusMessage = ""

    private var capturedCGImage: CGImage?
    private let capturer = ScreenCapturer()
    private let selector = RegionSelectorController()

    var hasCapture: Bool { capturedCGImage != nil }

    var selectionSummary: String? {
        guard let selection else { return nil }
        let rect = selection.rectInScreen
        return "\(Int(rect.width.rounded())) × \(Int(rect.height.rounded())) @ "
            + "(\(Int(rect.minX.rounded())), \(Int(rect.minY.rounded())))"
    }

    // MARK: Permission

    func refreshPermission() {
        permission = capturer.hasPermission() ? .authorized : .denied
    }

    /// Triggers the system prompt (first time) and re-reads the grant.
    func requestPermission() {
        capturer.requestPermission()
        refreshPermission()
        if permission == .denied {
            statusMessage = "尚未授权，请在系统设置中勾选 ScrollShot 后重开 App。"
        }
    }

    func openScreenRecordingSettings() {
        guard let url = AppConfig.screenRecordingSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Selection

    func selectRegion() async {
        let result: RegionSelection? = await withCheckedContinuation { continuation in
            selector.begin { continuation.resume(returning: $0) }
        }
        guard let result else {
            statusMessage = "已取消选区。"
            return
        }
        selection = result
        statusMessage = "已选择区域，点击「截图」抓取当前画面。"
    }

    // MARK: Capture

    func captureSelectedRegion() async {
        guard let selection else {
            statusMessage = "请先选择一个区域。"
            return
        }
        guard let displayID = selection.screen.displayID else {
            statusMessage = "无法识别所选显示器。"
            return
        }

        isBusy = true
        statusMessage = "正在截图…"
        defer { isBusy = false }

        let scale = selection.screen.backingScaleFactor
        let sourceRect = displayRelativeRect(for: selection)

        do {
            let cgImage = try await capturer.captureRegion(
                displayID: displayID,
                sourceRect: sourceRect,
                scale: scale
            )
            capturedCGImage = cgImage
            capturedImage = ImageUtils.nsImage(from: cgImage)
            statusMessage = "截图完成：\(cgImage.width) × \(cgImage.height) 像素。"
        } catch {
            if case CaptureError.permissionDenied = error {
                refreshPermission()
            }
            statusMessage = error.localizedDescription
        }
    }

    /// Converts a global AppKit rect (bottom-left origin) into a display-relative
    /// rect with a top-left origin, which is what ScreenCaptureKit expects.
    private func displayRelativeRect(for selection: RegionSelection) -> CGRect {
        let screenFrame = selection.screen.frame
        let rect = selection.rectInScreen
        return CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: Export

    func saveCapture() {
        guard let cgImage = capturedCGImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = AppConfig.defaultFileName()
        panel.directoryURL = AppConfig.defaultSaveDirectory
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ImageUtils.savePNG(cgImage, to: url)
            statusMessage = "已保存到 \(url.path)。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func copyCapture() {
        guard let cgImage = capturedCGImage else { return }
        if ImageUtils.copyToPasteboard(cgImage) {
            statusMessage = "已复制到剪贴板。"
        } else {
            statusMessage = "复制失败。"
        }
    }
}

extension NSScreen {
    /// The CoreGraphics display ID backing this screen, used to match `SCDisplay`.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
