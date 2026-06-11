import SwiftUI
import SwiftData

@main
struct MomentsApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Entry.self, MediaItem.self, Tag.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic   // 走 entitlements 里配置的 iCloud 私有库
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TimelineView()
        }
        .modelContainer(container)
    }
}
