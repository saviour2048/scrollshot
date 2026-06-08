import Foundation
import AppKit
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import CoreImage

extension NSScreen {
    /// The CoreGraphics display ID backing this screen, used to match `SCDisplay`.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound
    case emptyRegion
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得屏幕录制权限。"
        case .displayNotFound:
            return "找不到所选区域对应的显示器。"
        case .emptyRegion:
            return "选区为空。"
        case .captureFailed(let message):
            return "截图失败：\(message)"
        }
    }
}

/// Wraps ScreenCaptureKit for permission handling and single-frame region capture.
///
/// Permission is checked/requested through the CoreGraphics TCC entry points,
/// which are the canonical way to drive the "Screen Recording" privacy grant.
final class ScreenCapturer {

    // MARK: Permission

    /// Non-prompting check of the current screen-recording authorization.
    func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Prompts for screen-recording access if it has not been granted yet.
    /// Returns whether access is granted afterwards.
    @discardableResult
    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    // MARK: Capture

    /// Captures a single frame of `sourceRect` (points, top-left origin relative
    /// to the display) at the display's backing scale.
    func captureRegion(
        displayID: CGDirectDisplayID,
        sourceRect: CGRect,
        scale: CGFloat,
        excludingWindowIDs: [CGWindowID] = []
    ) async throws -> CGImage {
        guard sourceRect.width >= 1, sourceRect.height >= 1 else {
            throw CaptureError.emptyRegion
        }
        guard hasPermission() else {
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }

        let excluded = excludingWindowIDs.isEmpty
            ? []
            : content.windows.filter { excludingWindowIDs.contains($0.windowID) }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)

        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = max(1, Int((sourceRect.width * scale).rounded()))
        config.height = max(1, Int((sourceRect.height * scale).rounded()))
        config.showsCursor = false
        if #available(macOS 14.0, *) {
            config.scalesToFit = false
            config.captureResolution = .best
        }

        if #available(macOS 14.0, *) {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } else {
            return try await SingleFrameGrabber().grab(filter: filter, configuration: config)
        }
    }
}

/// macOS 13 fallback: spins up a short-lived `SCStream` and resolves with the
/// first complete frame. `SCScreenshotManager` only exists on macOS 14+.
private final class SingleFrameGrabber: NSObject, SCStreamOutput, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var stream: SCStream?
    private var finished = false
    private let ciContext = CIContext(options: nil)
    private let lock = NSLock()

    func grab(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            do {
                let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                self.stream = stream
                try stream.addStreamOutput(
                    self,
                    type: .screen,
                    sampleHandlerQueue: DispatchQueue(label: "com.scrollshot.framegrabber")
                )
                stream.startCapture { [weak self] error in
                    if let error { self?.finish(.failure(error)) }
                }
            } catch {
                finish(.failure(error))
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard isComplete(sampleBuffer), let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        finish(.success(cgImage))
    }

    /// Only act on frames whose status is `.complete`; dirty/idle frames are skipped.
    private func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let raw = info[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete
    }

    private func finish(_ result: Result<CGImage, Error>) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        let stream = self.stream
        self.stream = nil
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        stream?.stopCapture { _ in }
        switch result {
        case .success(let image):
            continuation?.resume(returning: image)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}
