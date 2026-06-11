import Foundation
import SwiftData

/// 一条记录：一段文字 + 若干媒体 + 若干标签，自动带时间戳。
@Model
final class Entry {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // 关系都设为可选 + 有反向，符合 CloudKit 同步要求。
    @Relationship(deleteRule: .cascade, inverse: \MediaItem.entry)
    var media: [MediaItem]? = []

    @Relationship(inverse: \Tag.entries)
    var tags: [Tag]? = []

    init(text: String = "", createdAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// 按插入顺序排好的媒体，方便界面展示。
    var sortedMedia: [MediaItem] {
        (media ?? []).sorted { $0.order < $1.order }
    }

    var tagList: [Tag] {
        (tags ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (media ?? []).isEmpty
    }
}
