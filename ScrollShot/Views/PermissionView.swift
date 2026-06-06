import SwiftUI

/// Shown until the "Screen Recording" privilege is granted. Walks the user
/// through requesting access and opening System Settings if needed.
struct PermissionView: View {
    @EnvironmentObject private var session: CaptureSession

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)

            Text("需要「屏幕录制」权限")
                .font(.title2.weight(.semibold))

            Text("ScrollShot 通过屏幕录制权限来抓取你框选的区域。\n所有处理均在本机完成，不会联网。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    session.requestPermission()
                } label: {
                    Text("请求授权")
                        .frame(maxWidth: 220)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("打开系统设置") {
                    session.openScreenRecordingSettings()
                }
                .buttonStyle(.link)

                Button("我已授权，重新检查") {
                    session.refreshPermission()
                }
                .buttonStyle(.link)
            }

            if session.permission == .denied, !session.statusMessage.isEmpty {
                Text(session.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("提示：首次授权后，可能需要退出并重新打开 App 才能生效。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionView()
        .environmentObject(CaptureSession())
        .frame(width: 480, height: 380)
}
