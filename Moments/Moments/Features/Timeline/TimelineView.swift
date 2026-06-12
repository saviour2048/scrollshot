import SwiftUI
import SwiftData

/// 主界面：按天分组的时间轴 + 标签筛选 + 浮动「+」记录入口。
struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @Query(sort: \Tag.createdAt) private var allTags: [Tag]

    @State private var showCompose = false
    @State private var showTagManager = false
    @State private var filterTag: Tag?
    @State private var searchText = ""

    private var filtered: [Entry] {
        var result = entries
        if let filterTag {
            result = result.filter { ($0.tags ?? []).contains { $0.id == filterTag.id } }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { entry in
                entry.text.localizedCaseInsensitiveContains(query)
                    || entry.tagList.contains { $0.name.localizedCaseInsensitiveContains(query) }
            }
        }
        return result
    }

    /// 按自然日分组，日期倒序。
    private var sections: [(date: Date, items: [Entry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    /// 「去年今日」：往年同月同日（排除今天）的记录。不受筛选/搜索影响。
    private var memories: [Entry] {
        let cal = Calendar.current
        let today = Date()
        return entries.filter {
            $0.createdAt.isSameMonthDay(as: today) && !cal.isDate($0.createdAt, inSameDayAs: today)
        }
    }

    var body: some View {
        NavigationStack {
            timeline
            .navigationTitle("时刻")
            .navigationDestination(for: Entry.self) { EntryDetailView(entry: $0) }
            .searchable(text: $searchText, prompt: "搜索文字或标签")
            .toolbar { filterToolbar }
            .overlay(alignment: .bottomTrailing) { addButton }
            .sheet(isPresented: $showCompose) { ComposeView() }
            .sheet(isPresented: $showTagManager) {
                NavigationStack { TagManagerView() }
            }
            .task { TagSeeder.seedIfNeeded(context) }
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !memories.isEmpty {
                    NavigationLink {
                        MemoriesView(entries: memories)
                    } label: {
                        MemoriesBanner(count: memories.count)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                if filtered.isEmpty {
                    EmptyTimelineView(isFiltering: filterTag != nil || !searchText.isEmpty)
                        .padding(.top, 48)
                } else {
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
                Divider()
                Button {
                    showTagManager = true
                } label: {
                    Label("管理标签…", systemImage: "slider.horizontal.3")
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

/// 「去年今日」入口横幅。
private struct MemoriesBanner: View {
    let count: Int
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.22)))
            VStack(alignment: .leading, spacing: 2) {
                Text("去年今日")
                    .font(.subheadline.weight(.semibold))
                Text("有 \(count) 条往年的今天，点开回看")
                    .font(.caption)
                    .opacity(0.9)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: "#FF8A65"), Color(hex: "#EC407A")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
    }
}

private struct EmptyTimelineView: View {
    let isFiltering: Bool
    var body: some View {
        ContentUnavailableView {
            Label(isFiltering ? "没有匹配的记录" : "还没有记录", systemImage: "sparkles")
        } description: {
            Text(isFiltering ? "换个标签或关键词试试，或点右下角「+」记录新内容。" : "点右下角「+」，随手记下此刻的想法吧。")
        }
    }
}

#Preview {
    TimelineView()
        .modelContainer(for: [Entry.self, MediaItem.self, Tag.self], inMemory: true)
}
