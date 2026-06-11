import SwiftUI

/// 一枚彩色标签。selected 控制是否高亮（用于筛选/选择场景）。
struct TagChip: View {
    let name: String
    let colorHex: String
    var selected: Bool = true

    private var color: Color { Color(hex: colorHex) }

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(selected ? color : .secondary)
            .background(
                Capsule().fill(selected ? color.opacity(0.16) : Color(.secondarySystemFill))
            )
            .overlay(
                Capsule().stroke(selected ? color.opacity(0.35) : .clear, lineWidth: 1)
            )
    }
}

extension TagChip {
    init(tag: Tag, selected: Bool = true) {
        self.init(name: tag.name, colorHex: tag.colorHex, selected: selected)
    }
}
