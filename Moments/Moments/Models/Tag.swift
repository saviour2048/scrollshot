import Foundation
import SwiftData

/// 彩色标签，可在记录页即时新建，也用于时间轴筛选。
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#5E9EFF"
    var createdAt: Date = Date()

    var entries: [Entry]? = []

    init(name: String, colorHex: String = "#5E9EFF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    var entryCount: Int { entries?.count ?? 0 }
}

extension Tag {
    /// 新建标签时可选的一组好看的颜色。
    static let palette: [String] = [
        "#5E9EFF", "#FF8A65", "#66BB6A", "#FFCA28",
        "#BA68C8", "#26C6DA", "#EC407A", "#8D6E63"
    ]
}
