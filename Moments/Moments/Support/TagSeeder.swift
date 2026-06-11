import Foundation
import SwiftData

/// 首次启动时预置几个常用标签，降低上手门槛。
enum TagSeeder {
    private static let defaults: [(String, String)] = [
        ("想法", "#5E9EFF"),
        ("生活", "#66BB6A"),
        ("工作", "#FF8A65"),
        ("心情", "#EC407A")
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Tag>())) ?? 0
        guard count == 0 else { return }
        for (name, hex) in defaults {
            context.insert(Tag(name: name, colorHex: hex))
        }
        try? context.save()
    }
}
