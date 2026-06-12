import SwiftUI

/// 心情：用 emoji + 颜色表达，记录时可选打一个。
enum Mood: String, CaseIterable, Identifiable {
    case great   // 超棒
    case good    // 不错
    case meh     // 一般
    case down    // 低落
    case awful   // 糟糕

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good:  return "🙂"
        case .meh:   return "😐"
        case .down:  return "😔"
        case .awful: return "😣"
        }
    }

    var label: String {
        switch self {
        case .great: return "超棒"
        case .good:  return "不错"
        case .meh:   return "一般"
        case .down:  return "低落"
        case .awful: return "糟糕"
        }
    }

    /// 心情条/选中态的主题色。
    var color: Color {
        switch self {
        case .great: return Color(hex: "#FFB300")
        case .good:  return Color(hex: "#66BB6A")
        case .meh:   return Color(hex: "#90A4AE")
        case .down:  return Color(hex: "#5E9EFF")
        case .awful: return Color(hex: "#EF5350")
        }
    }
}
