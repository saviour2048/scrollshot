import SwiftUI
import AppKit
import CoreGraphics
import ApplicationServices
import KeyboardShortcuts

// MARK: - Apple system color tokens (Light)

private extension Color {
    static let ssText      = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let ssSecondary = Color(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255)
    static let ssTertiary  = Color(red: 0x6C / 255, green: 0x6C / 255, blue: 0x70 / 255)
    static let ssMuted     = Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255)
    static let ssBlue      = Color(red: 0x00 / 255, green: 0x7A / 255, blue: 0xFF / 255)
    static let ssGreen     = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)
    static let ssOrange    = Color(red: 0xFF / 255, green: 0x95 / 255, blue: 0x00 / 255)
    static let ssPage      = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let ssHairline  = Color.black.opacity(0.08)
}

struct PreferencesView: View {
    @State private var screenGranted = false
    @State private var accessibilityGranted = false

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                shortcutCard
                permissionCard
                saveCard
                aboutCard
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.ssPage)
        .frame(width: 480, height: 600)
        .onAppear(perform: refresh)
        .onReceive(refreshTimer) { _ in refresh() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ScrollShot 设置")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.ssText)
            Text("截图 · 长截图 · 标注，全在本机完成")
                .font(.system(size: 15))
                .foregroundColor(.ssMuted)
        }
    }

    private var shortcutCard: some View {
        Card(title: "全局快捷键") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("截图 / 长截图").font(.system(size: 14)).foregroundColor(.ssText)
                    Text("任意时刻按下，唤起框选").font(.system(size: 12)).foregroundColor(.ssMuted)
                }
                Spacer()
                KeyboardShortcuts.Recorder(for: .captureRegion)
            }
        }
    }

    private var permissionCard: some View {
        Card(title: "权限") {
            PermissionRow(
                title: "屏幕录制",
                detail: "截图、长截图都必需",
                granted: screenGranted
            ) { open(AppConfig.screenRecordingSettingsURL) }

            Divider().overlay(Color.ssHairline)

            PermissionRow(
                title: "辅助功能",
                detail: "长截图的「自动滚动」需要（手动滚轮则不需要）",
                granted: accessibilityGranted
            ) { open(AppConfig.accessibilitySettingsURL) }

            Text("授予后若仍不生效，请退出并重新打开 App。")
                .font(.system(size: 12))
                .foregroundColor(.ssMuted)
                .padding(.top, 2)
        }
    }

    private var saveCard: some View {
        Card(title: "保存") {
            Text("截图完成后自动保存到桌面，并同时复制到剪贴板。")
                .font(.system(size: 14))
                .foregroundColor(.ssTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutCard: some View {
        Card(title: "关于") {
            HStack {
                Text("版本").font(.system(size: 14)).foregroundColor(.ssText)
                Spacer()
                Text(versionString).font(.system(size: 14)).foregroundColor(.ssMuted)
            }
        }
    }

    // MARK: Helpers

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func refresh() {
        screenGranted = CGPreflightScreenCaptureAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Building blocks

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.ssMuted)
                .tracking(0.2)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.ssText)
                Text(detail).font(.system(size: 12)).foregroundColor(.ssMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            StatusBadge(granted: granted)
            Button(action: openSettings) {
                Text("打开设置")
                    .font(.system(size: 13))
                    .foregroundColor(.ssSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StatusBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(granted ? Color.ssGreen : Color.ssOrange)
                .frame(width: 7, height: 7)
            Text(granted ? "已授权" : "未授权")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(granted ? .ssGreen : .ssOrange)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            (granted ? Color.ssGreen : Color.ssOrange).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }
}

#Preview {
    PreferencesView()
}
