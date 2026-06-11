import Foundation
import SwiftData

/// 媒体类型。MVP 只用 photo，video / audio 已为 v2 预留。
enum MediaKind: String, Codable, CaseIterable {
    case photo
    case video
    case audio
}

/// 一条记录里的单个媒体。二进制存外部存储，CloudKit 会作为 CKAsset 同步。
@Model
final class MediaItem {
    var id: UUID = UUID()
    var kindRaw: String = MediaKind.photo.rawValue
    var order: Int = 0
    var createdAt: Date = Date()

    @Attribute(.externalStorage) var data: Data?

    var entry: Entry?

    var kind: MediaKind { MediaKind(rawValue: kindRaw) ?? .photo }

    init(kind: MediaKind = .photo, data: Data?, order: Int = 0) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.data = data
        self.order = order
        self.createdAt = Date()
    }
}
