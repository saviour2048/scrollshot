import SwiftUI
import SwiftData

/// 「去年今日」：往年同一个月日的记录，按年份分组回看。
struct MemoriesView: View {
    let entries: [Entry]

    /// 按年份倒序分组（去年、前年…）。
    private var sections: [(year: Int, items: [Entry])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: entries) { cal.component(.year, from: $0.createdAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections, id: \.year) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(yearsAgoLabel(section.year))
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(section.items) { entry in
                            NavigationLink(value: entry) {
                                TimelineRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("去年今日")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func yearsAgoLabel(_ year: Int) -> String {
        let diff = Calendar.current.component(.year, from: Date()) - year
        switch diff {
        case 1: return "去年的今天"
        case 2: return "前年的今天"
        default: return "\(diff) 年前的今天"
        }
    }
}

extension Date {
    /// 是否和今天是同一个「月-日」（忽略年份）。
    func isSameMonthDay(as other: Date, calendar: Calendar = .current) -> Bool {
        let a = calendar.dateComponents([.month, .day], from: self)
        let b = calendar.dateComponents([.month, .day], from: other)
        return a.month == b.month && a.day == b.day
    }
}
