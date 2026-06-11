import SwiftUI
import SwiftData

/// 记录详情：完整文字、大图、标签，可编辑或删除。
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: Entry

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var previewItem: MediaItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !entry.sortedMedia.isEmpty {
                    photoGrid
                }

                if !entry.tagList.isEmpty {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(entry.tagList) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(entry.createdAt.dayHeader())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("编辑", systemImage: "pencil") }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ComposeView(editing: entry)
        }
        .fullScreenCover(item: $previewItem) { item in
            PhotoPreview(item: item)
        }
        .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                context.delete(entry)
                try? context.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
            Text(entry.createdAt.timeShort())
            Text("·")
            Text(entry.createdAt.weekdayShort())
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(entry.sortedMedia) { item in
                Button {
                    previewItem = item
                } label: {
                    MediaThumbnail(item: item, size: 110)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 全屏看图。
private struct PhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = item.data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.25))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
