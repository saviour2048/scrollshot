import Foundation

extension Date {
    /// 时间轴分组标题：今天 / 昨天 / 2026年6月11日。
    func dayHeader() -> String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "今天" }
        if cal.isDateInYesterday(self) { return "昨天" }
        return formatted(
            Date.FormatStyle()
                .year().month(.wide).day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    /// 卡片上的星期，例如「周三」。
    func weekdayShort() -> String {
        formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    /// 记录的具体时刻，例如「14:30」。
    func timeShort() -> String {
        formatted(.dateTime.hour().minute())
    }
}
