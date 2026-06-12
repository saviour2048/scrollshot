import SwiftUI
import SwiftData
import AVKit
import MapKit

/// 记录详情：完整文字、大图/视频、语音播放、标签，可编辑或删除。
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: Entry

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var previewItem: MediaItem?

    /// 照片和视频走网格 + 全屏预览；语音单独列成播放条。
    private var visualMedia: [MediaItem] { entry.sortedMedia.filter { $0.kind != .audio } }
    private var audioMedia: [MediaItem] { entry.sortedMedia.filter { $0.kind == .audio } }

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

                if !visualMedia.isEmpty {
                    mediaGrid
                }

                if !audioMedia.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(audioMedia) { item in
                            AudioPlayerView(data: item.data)
                        }
                    }
                }

                if entry.hasLocation {
                    locationCard
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
            MediaPreview(item: item)
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
            if let mood = entry.mood {
                Text("·")
                Text("\(mood.emoji) \(mood.label)")
                    .foregroundStyle(mood.color)
            }
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    /// 地点卡片：小地图 + 地名，点一下用系统地图打开。
    private var locationCard: some View {
        let coordinate = CLLocationCoordinate2D(latitude: entry.latitude ?? 0,
                                                longitude: entry.longitude ?? 0)
        return VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(entry.placeName ?? "这里", coordinate: coordinate)
            }
            .frame(height: 140)
            .disabled(true)
            .allowsHitTesting(false)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text(entry.placeName ?? "已记录的位置")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { openInMaps(coordinate) }
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = entry.placeName ?? "记录地点"
        item.openInMaps()
    }

    private var mediaGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(visualMedia) { item in
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

/// 全屏预览：照片直接看，视频写到临时文件后用系统播放器播。
private struct MediaPreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem

    @State private var player: AVPlayer?
    @State private var tempURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if item.kind == .video {
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    ProgressView().tint(.white)
                }
            } else if let data = item.data, let image = UIImage(data: data) {
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
        .onAppear(perform: preparePlayer)
        .onDisappear {
            player?.pause()
            if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        }
    }

    private func preparePlayer() {
        guard item.kind == .video, player == nil, let data = item.data else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(item.id.uuidString + ".mov")
        do { try data.write(to: url) } catch { return }
        tempURL = url
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let avPlayer = AVPlayer(url: url)
        player = avPlayer
        avPlayer.play()
    }
}
