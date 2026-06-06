import SwiftUI

struct MainView: View {
    @EnvironmentObject private var session: CaptureSession

    var body: some View {
        Group {
            switch session.permission {
            case .authorized:
                captureWorkspace
            case .denied, .unknown:
                PermissionView()
            }
        }
        .frame(minWidth: 480, minHeight: 380)
        .task { session.refreshPermission() }
    }

    private var captureWorkspace: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            PreviewView(image: session.capturedImage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            statusBar
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await session.selectRegion() }
            } label: {
                Label("选择区域", systemImage: "rectangle.dashed")
            }
            .disabled(session.isBusy)

            Button {
                Task { await session.captureSelectedRegion() }
            } label: {
                Label("截图", systemImage: "camera")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(session.selection == nil || session.isBusy)

            Spacer()

            Button {
                session.saveCapture()
            } label: {
                Label("保存 PNG", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!session.hasCapture)

            Button {
                session.copyCapture()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!session.hasCapture)
        }
        .padding(12)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if session.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let summary = session.selectionSummary {
                Text(summary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        session.statusMessage.isEmpty ? "先「选择区域」，再「截图」。" : session.statusMessage
    }
}

#Preview {
    MainView()
        .environmentObject(CaptureSession())
}
