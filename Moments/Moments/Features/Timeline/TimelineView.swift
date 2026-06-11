import SwiftUI
import SwiftData

/// 主界面：按天分组的时间轴 + 标签筛选 + 浮动「+」记录入口。
struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(sort: \Tag.createdAt) private var allTags: [Tag]

    @State private var showCompose = false
    @State private var filterTag: Tag?

    private var filtered: [Entry] {
        guard let filterTag else { return entries }
        return entries.filter { ($0.tags ?? []).contains { $0.id == filterTag.id } }
    }

    /// 按自然日分组，日期倒序。
    private var sections: [(date: Date, items: [Entry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyTimelineView(isFiltering: filterTag != nil)
                } else {
                    timeline
                }
            }
            .navigationTitle("时刻")
            .navigationDestination(for: Entry.self) { EntryDetailView(entry: $0) }
            .toolbar { filterToolbar }
            .overlay(alignment: .bottomTrailing) { addButton }
            .sheet(isPresented: $showCompose) { ComposeView() }
            .task { TagSeeder.seedIfNeeded(context) }
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sections, id: \.date) { section in
                    Section {
                        ForEach(section.items) { entry in
                            NavigationLink(value: entry) {
                                TimelineRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        DateHeader(date: section.date)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    filterTag = nil
                } label: {
                    Label("全部", systemImage: filterTag == nil ? "checkmark" : "tray.full")
                }
                if !allTags.isEmpty { Divider() }
                ForEach(allTags) { tag in
                    Button {
                        filterTag = (filterTag?.id == tag.id) ? nil : tag
                    } label: {
                        Label(tag.name, systemImage: filterTag?.id == tag.id ? "checkmark" : "tag")
                    }
                }
            } label: {
                Image(systemName: filterTag == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    private var addButton: some View {
        Button {
            showCompose = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .accentColor.opacity(0.4), radius: 10, y: 4)
        }
        .padding(24)
    }
}

/// 分组的日期标题（吸顶）。
private struct DateHeader: View {
    let date: Date
    var body: some View {
        HStack(spacing: 6) {
            Text(date.dayHeader())
                .font(.subheadline.weight(.semibold))
            Text(date.weekdayShort())
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(.background)
    }
}

private struct EmptyTimelineView: View {
    let isFiltering: Bool
    var body: some View {
        ContentUnavailableView {
            Label(isFiltering ? "这个标签下还没有记录" : "还没有记录", systemImage: "sparkles")
        } description: {
            Text(isFiltering ? "换个标签，或点右下角「+」记录新内容。" : "点右下角「+」，随手记下此刻的想法吧。")
        }
    }
}

#Preview {
    TimelineView()
        .modelContainer(for: [Entry.self, MediaItem.self, Tag.self], inMemory: true)
}
