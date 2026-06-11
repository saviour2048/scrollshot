import SwiftUI
import AVFoundation

/// 音频播放控制器：包一层 AVAudioPlayer，给界面暴露播放状态和进度。
final class AudioPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(_ data: Data) {
        guard player == nil else { return }
        player = try? AVAudioPlayer(data: data)
        player?.delegate = self
        duration = player?.duration ?? 0
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player?.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        isPlaying = false
        progress = 0
        currentTime = 0
    }
}

/// 一条语音的播放卡片：播放/暂停 + 进度条 + 时长。
struct AudioPlayerView: View {
    let data: Data?
    @StateObject private var playback = AudioPlayback()

    var body: some View {
        HStack(spacing: 12) {
            Button(action: playback.toggle) {
                Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: playback.progress)
                    .tint(.accentColor)
                Text("\(Self.format(playback.currentTime)) / \(Self.format(playback.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onAppear { if let data { playback.load(data) } }
        .onDisappear { playback.stop() }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
