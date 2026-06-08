import SwiftUI

/// The 截图中心 main window: normal capture on top, scroll (long) capture below
/// with a manual/auto mode switch and a live preview.
struct CaptureCenterView: View {
    @ObservedObject var model: CaptureCenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ScrollShot 截图中心")
                .font(.title2.weight(.semibold))

            normalSection
            Divider()
            scrollSection

            if !model.message.isEmpty {
                Text(model.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 440, height: 600, alignment: .topLeading)
    }

    // MARK: Normal capture

    private var normalSection: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("普通截图").font(.headline)
                    Text("框选 → 标注 → 存桌面 / 复制。也可用全局快捷键。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("截图") { model.normalCapture() }
                    .controlSize(.large)
                    .disabled(model.isCapturing)
            }
            .padding(6)
        }
    }

    // MARK: Scroll capture

    private var scrollSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("滚动截图（长截图）").font(.headline)

                Picker("滚动方式", selection: $model.autoScroll) {
                    Text("手动滚轮").tag(false)
                    Text("自动滚动").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(model.isCapturing)

                Text(model.autoScroll
                     ? "选择区域后，App 自动向下滚动并拼接，到底自动停止。需「辅助功能」权限。"
                     : "选择区域后，自己向下慢慢滚动，App 按节奏抓帧拼接。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                switch model.phase {
                case .idle:
                    Button("选择区域并开始") { model.startScroll() }
                        .controlSize(.large)
                case .capturing:
                    capturingControls
                case .finished:
                    finishedControls
                }

                previewBox
            }
            .padding(6)
        }
    }

    private var capturingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(model.autoScroll ? "自动滚动中…" : "请向下慢慢滚动页面…")
                    .font(.callout)
            }
            Text("已拼接 \(model.height) px · \(model.frames) 帧")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack {
                Button("结束并保存") { model.finishScroll() }
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                Button("取消") { model.cancelScroll() }
            }
        }
    }

    private var finishedControls: some View {
        HStack {
            Button("再截一张") { model.startOver() }
                .controlSize(.large)
        }
    }

    private var previewBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .underPageBackgroundColor))
            if let image = model.preview {
                ScrollView(.vertical) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                .padding(6)
            } else {
                Text("预览会显示在这里")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 240)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor))
        )
    }
}

#Preview {
    CaptureCenterView(model: .shared)
}
