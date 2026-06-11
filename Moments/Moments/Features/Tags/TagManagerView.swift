import SwiftUI
import SwiftData

/// 标签管理：列表 + 点开编辑（改名/改色/合并），左滑删除。
struct TagManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.createdAt) private var tags: [Tag]
    @State private var editingTag: Tag?

    var body: some View {
        List {
            ForEach(tags) { tag in
                Button {
                    editingTag = tag
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 14, height: 14)
                        Text(tag.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(tag.entryCount) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView("还没有标签", systemImage: "tag",
                                       description: Text("在记录页里可以随时新建标签。"))
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditSheet(tag: tag)
                .presentationDetents([.medium, .large])
        }
    }

    private func delete(at offsets: IndexSet) {
        // 删除标签不影响记录本身，只是记录不再带这个标签。
        for index in offsets { context.delete(tags[index]) }
        try? context.save()
    }
}

/// 编辑单个标签：名称、颜色，或合并进另一个标签。
private struct TagEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var tag: Tag
    @Query(sort: \Tag.createdAt) private var allTags: [Tag]

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("标签名", text: $tag.name)
                }

                Section("颜色") {
                    FlowLayout(spacing: 12, lineSpacing: 12) {
                        ForEach(Tag.palette, id: \.self) { hex in
                            Button {
                                tag.colorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 34, height: 34)
                                    if tag.colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if allTags.count > 1 {
                    Section {
                        Menu {
                            ForEach(allTags.filter { $0.id != tag.id }) { other in
                                Button(other.name) { merge(into: other) }
                            }
                        } label: {
                            Label("合并到其他标签…", systemImage: "arrow.triangle.merge")
                        }
                    } footer: {
                        Text("把这个标签下的所有记录挪到目标标签，然后删除本标签。")
                    }
                }
            }
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func merge(into target: Tag) {
        for entry in tag.entries ?? [] {
            if !(entry.tags ?? []).contains(where: { $0.id == target.id }) {
                entry.tags?.append(target)
            }
        }
        context.delete(tag)
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { TagManagerView() }
        .modelContainer(for: [Entry.self, MediaItem.self, Tag.self], inMemory: true)
}
