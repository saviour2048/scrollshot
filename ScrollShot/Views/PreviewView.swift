import SwiftUI

/// Shows the most recent captured frame, or an empty placeholder.
struct PreviewView: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            if let image {
                ScrollView([.vertical, .horizontal]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有截图")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击「选择区域」框选屏幕，再点「截图」。")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    PreviewView(image: nil)
        .frame(width: 480, height: 320)
}
