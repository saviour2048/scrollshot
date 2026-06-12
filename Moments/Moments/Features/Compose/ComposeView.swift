import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// 记录页里待保存的一个媒体（照片 / 视频 / 语音）。
struct MediaDraft: Identifiable {
    let id = UUID()
    var kind: MediaKind
    var data: Data
}

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
    /// 待保存的媒体：编辑模式下已有的媒体也会先转成 draft 一起管理。
    @State private var drafts: [MediaDraft] = []

    @State private var showRecorder = false
    @State private var showNewTag = false
    @State private var newTagName = ""

    @State private var mood: Mood?
    @State private var place: LocationProvider.Place?
    @State private var fetchingLocation = false
    @State private var locationDenied = false
    @StateObject private var locationProvider = LocationProvider()

    @FocusState private var textFocused: Bool

    private var isEditing: Bool { editing != nil }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !drafts.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    textField
                    mediaSection
                    moodSection
                    locationSection
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
            .onChange(of: pickerItems) { _, items in loadPickedItems(items) }
            .onAppear(perform: loadEditingState)
            .sheet(isPresented: $showRecorder) {
                AudioRecordSheet { data in
                    drafts.append(MediaDraft(kind: .audio, data: data))
                }
            }
            .alert("新建标签", isPresented: $showNewTag) {
                TextField("标签名", text: $newTagName)
                Button("添加", action: addNewTag)
                Button("取消", role: .cancel) { newTagName = "" }
            }
            .alert("需要定位权限", isPresented: $locationDenied) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请到 设置 ▸ 隐私与安全性 ▸ 定位服务 里允许「时刻」使用定位。")
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

    private var mediaSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 9,
                             matching: .any(of: [.images, .videos])) {
                    addTile(symbol: "photo.badge.plus", title: "照片/视频")
                }

                Button {
                    showRecorder = true
                } label: {
                    addTile(symbol: "mic.badge.plus", title: "语音")
                }
                .buttonStyle(.plain)

                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    draftTile(draft, index: index)
                }
            }
        }
    }

    private func addTile(symbol: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title2)
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemFill))
        )
    }

    private func draftTile(_ draft: MediaDraft, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch draft.kind {
                case .photo:
                    if let image = UIImage(data: draft.data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                case .video:
                    ZStack {
                        Color.black.opacity(0.75)
                        VStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("视频").font(.caption2)
                        }
                        .foregroundStyle(.white)
                    }
                case .audio:
                    ZStack {
                        Color(.tertiarySystemFill)
                        VStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text("语音").font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                drafts.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("心情")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Mood.allCases) { m in
                    let selected = mood == m
                    Button {
                        mood = selected ? nil : m   // 再点一次取消
                    } label: {
                        VStack(spacing: 3) {
                            Text(m.emoji)
                                .font(.title2)
                            Text(m.label)
                                .font(.caption2)
                                .foregroundStyle(selected ? m.color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? m.color.opacity(0.15) : Color(.secondarySystemFill))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(selected ? m.color : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地点")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let place {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(place.name ?? "已记录当前位置")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        self.place = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemFill))
                )
            } else {
                Button(action: addLocation) {
                    HStack(spacing: 8) {
                        if fetchingLocation {
                            ProgressView()
                        } else {
                            Image(systemName: "location")
                        }
                        Text(fetchingLocation ? "定位中…" : "添加当前位置")
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemFill))
                    )
                }
                .buttonStyle(.plain)
                .disabled(fetchingLocation)
            }
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

    private func addLocation() {
        fetchingLocation = true
        Task {
            let result = await locationProvider.fetch()
            fetchingLocation = false
            if let result {
                place = result
            } else if locationProvider.state == .denied {
                locationDenied = true
            }
        }
    }

    private func loadPickedItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        drafts.append(MediaDraft(kind: isVideo ? .video : .photo, data: data))
                    }
                }
            }
            await MainActor.run { pickerItems = [] }
        }
    }

    private func loadEditingState() {
        guard let editing, drafts.isEmpty, text.isEmpty else { return }
        text = editing.text
        selectedTagIDs = Set(editing.tagList.map(\.id))
        mood = editing.mood
        if let lat = editing.latitude, let lon = editing.longitude {
            place = LocationProvider.Place(latitude: lat, longitude: lon, name: editing.placeName)
        }
        drafts = editing.sortedMedia.compactMap { item in
            guard let data = item.data else { return nil }
            return MediaDraft(kind: item.kind, data: data)
        }
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
        entry.mood = mood
        entry.latitude = place?.latitude
        entry.longitude = place?.longitude
        entry.placeName = place?.name
        entry.media = drafts.enumerated().map { index, draft in
            MediaItem(kind: draft.kind, data: draft.data, order: index)
        }

        try? context.save()
        dismiss()
    }
}

#Preview {
    ComposeView()
        .modelContainer(for: [Entry.self, MediaItem.self, Tag.self], inMemory: true)
}
