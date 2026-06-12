import SwiftUI

/// 时间轴上的一行：左侧时间线（时间点 + 竖线），右侧记录卡片。
struct TimelineRowView: View {
    let entry: Entry

    private var accent: Color {
        if let first = entry.tagList.first { return Color(hex: first.colorHex) }
        return .accentColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            gutter
            card
        }
        .padding(.vertical, 6)
    }

    private var gutter: some View {
        VStack(spacing: 4) {
            Text(entry.createdAt.timeShort())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 44)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.mood != nil || entry.placeName != nil {
                HStack(spacing: 8) {
                    if let mood = entry.mood {
                        Text(mood.emoji)
                            .font(.subheadline)
                    }
                    if let place = entry.placeName {
                        Label(place, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(.body)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !entry.sortedMedia.isEmpty {
                MediaThumbnailStrip(media: entry.sortedMedia)
            }

            if !entry.tagList.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(entry.tagList) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// 卡片里的横向缩略图条，最多显示 4 张，多余的用 +N 表示。
struct MediaThumbnailStrip: View {
    let media: [MediaItem]
    private let maxShown = 4

    var body: some View {
        let shown = Array(media.prefix(maxShown))
        let extra = media.count - shown.count
        HStack(spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                ZStack(alignment: .bottomTrailing) {
                    MediaThumbnail(item: item, size: 72)
                    if index == shown.count - 1, extra > 0 {
                        Text("+\(extra)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Color.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// 单张媒体缩略图：照片直接显示，视频异步取首帧 + 播放角标，语音用波形图标。
struct MediaThumbnail: View {
    let item: MediaItem
    var size: CGFloat = 72

    @State private var videoFrame: UIImage?

    var body: some View {
        Group {
            switch item.kind {
            case .photo:
                if let data = item.data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder("photo")
                }
            case .video:
                ZStack {
                    if let videoFrame {
                        Image(uiImage: videoFrame)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.45))
                }
                .task { videoFrame = await VideoThumbnailCache.shared.image(for: item) }
            case .audio:
                placeholder("waveform")
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func placeholder(_ symbol: String) -> some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
        }
    }
}
