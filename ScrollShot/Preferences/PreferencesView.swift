import SwiftUI
import AppKit
import KeyboardShortcuts

struct PreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ScrollShot 偏好设置")
                .font(.title3.weight(.semibold))

            GroupBox("全局快捷键") {
                HStack {
                    Text("截图")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .captureRegion)
                }
                .padding(6)
            }

            GroupBox("权限") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ScrollShot 需要「屏幕录制」权限才能截图。")
                        .foregroundStyle(.secondary)
                    Button("打开 屏幕录制 设置") {
                        if let url = AppConfig.screenRecordingSettingsURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox("保存") {
                Text("截图自动保存到桌面，并同时复制到剪贴板。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: 360)
    }
}

#Preview {
    PreferencesView()
}
