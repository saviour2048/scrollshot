import UIKit
import AVFoundation

/// 视频缩略图：数据在 SwiftData 里是二进制，取首帧需要先落临时文件再解码，
/// 比较贵，所以按 MediaItem id 用 NSCache 缓存。
final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private let cache = NSCache<NSUUID, UIImage>()

    func image(for item: MediaItem) async -> UIImage? {
        let key = item.id as NSUUID
        if let hit = cache.object(forKey: key) { return hit }
        guard item.kind == .video, let data = item.data else { return nil }
        guard let image = await Self.firstFrame(of: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// 取视频第一帧（写临时文件 → AVAssetImageGenerator → 删临时文件）。
    static func firstFrame(of data: Data) async -> UIImage? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        do { try data.write(to: url) } catch { return nil }
        defer { try? FileManager.default.removeItem(at: url) }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let result = try? await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600)) else {
            return nil
        }
        return UIImage(cgImage: result.image)
    }
}
