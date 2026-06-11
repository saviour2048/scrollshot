import SwiftUI
import AVFoundation

/// 录音弹层：大按钮开始/结束，结束后把数据回传给记录页。
struct AudioRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorder()
    @State private var permissionDenied = false

    /// 录音完成回调，参数是 m4a 数据。
    var onFinish: (Data) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text(recorder.isRecording ? AudioPlayerView.format(recorder.duration) : "点击开始录音")
                .font(recorder.isRecording ? .largeTitle.monospacedDigit() : .headline)
                .foregroundStyle(recorder.isRecording ? .primary : .secondary)
                .contentTransition(.numericText())

            Button(action: toggle) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.accentColor)
                        .frame(width: 84, height: 84)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            if recorder.isRecording {
                Button("取消录音", role: .destructive) {
                    recorder.cancel()
                    dismiss()
                }
                .font(.subheadline)
            } else {
                Text("录好后会作为语音附在这条记录里")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 36)
        .presentationDetents([.height(280)])
        .onDisappear { recorder.cancel() }
        .alert("需要麦克风权限", isPresented: $permissionDenied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请到 设置 ▸ 隐私与安全性 ▸ 麦克风 里允许「时刻」使用麦克风。")
        }
    }

    private func toggle() {
        if recorder.isRecording {
            if let data = recorder.stop() {
                onFinish(data)
            }
            dismiss()
        } else {
            Task {
                guard await AVAudioApplication.requestRecordPermission() else {
                    permissionDenied = true
                    return
                }
                try? recorder.start()
            }
        }
    }
}
