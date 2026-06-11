import SwiftUI
import SwiftData
import PhotosUI

/// 快速记录页，也复用为编辑页（传入 editing）。
struct ComposeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.createdAt) private var allTags: [Tag]

    /// 传入则为编辑现有记录；为 nil 则新建。
    var editing: Entry?

    @State private var text: String = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var pickerItems: [PhotosPickerItem] = []
    /// 待保存的照片：编辑模式下已有的媒体也会先转成这里的 data 一起管理。
    @State private var photos: [Data] = []

    @State private var showNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Tag.palette.first ?? "#5E9EFF"

    @FocusState private var textFocused: Bool

    private var isEditing: Bool { editing != nil }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    textField
                    photoSection
                    tagSection
                }
                .padding()
            }
            .navigationTitle(isEditing ? "编辑记录" : "记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: pickerItems) { _, items in loadPickedPhotos(items) }
            .onAppear(perform: loadEditingState)
            .alert("新建标签", isPresented: $showNewTag) {
                TextField("标签名", text: $newTagName)
                Button("添加", action: addNewTag)
                Button("取消", role: .cancel) { newTagName = "" }
            }
        }
    }

    // MARK: - Sections

    private var textField: some View {
        TextField("此刻在想什么…", text: $text, axis: .vertical)
            .font(.body)
            .lineLimit(4...)
            .focused($textFocused)
            .onAppear { if !isEditing { textFocused = true } }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                            Text("照片")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemFill))
                        )
                    }

                    ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                        thumbnail(data: data, index: index)
                    }
                }
            }
        }
    }

    private func thumbnail(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button {
                photos.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(allTags) { tag in
                    Button {
                        toggle(tag)
                    } label: {
                        TagChip(tag: tag, selected: selectedTagIDs.contains(tag.id))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    showNewTag = true
                } label: {
                    Label("新建", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(.secondary)
                        .background(Capsule().strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [3])))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ tag: Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }

    private func addNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        newTagName = ""
        guard !name.isEmpty else { return }
        // 同名复用，避免重复。
        if let existing = allTags.first(where: { $0.name == name }) {
            selectedTagIDs.insert(existing.id)
            return
        }
        let color = Tag.palette[allTags.count % Tag.palette.count]
        let tag = Tag(name: name, colorHex: color)
        context.insert(tag)
        selectedTagIDs.insert(tag.id)
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { photos.append(data) }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
    }

    private func loadEditingState() {
        guard let editing, photos.isEmpty, text.isEmpty else { return }
        text = editing.text
        selectedTagIDs = Set(editing.tagList.map(\.id))
        photos = editing.sortedMedia.compactMap { $0.data }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenTags = allTags.filter { selectedTagIDs.contains($0.id) }

        let entry: Entry
        if let editing {
            entry = editing
            entry.text = trimmed
            entry.updatedAt = Date()
            // 媒体以重建方式同步：删旧建新（MVP 数量小，简单可靠）。
            for old in entry.media ?? [] { context.delete(old) }
        } else {
            entry = Entry(text: trimmed)
            context.insert(entry)
        }

        entry.tags = chosenTags
        entry.media = photos.enumerated().map { index, data in
            MediaItem(kind: .photo, data: data, order: index)
        }

        try? context.save()
        dismiss()
    }
}

#Preview {
    ComposeView()
        .modelContainer(for: [Entry.self, MediaItem.self, Tag.self], inMemory: true)
}
