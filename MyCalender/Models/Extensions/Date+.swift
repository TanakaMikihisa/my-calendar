import Foundation

extension Date {
    func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func endOfDay(in calendar: Calendar = .current) -> Date {
        let start = startOfDay(in: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
    }

    /// "HH:mm" 形式で時刻を返す
    func toTimeString(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }

    /// 今日の日付に "HH:mm" を適用した Date を返す（テンプレ時刻の編集用）
    static func fromTimeString(_ time: String, calendar: Calendar = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = formatter.date(from: time) else { return nil }
        let comps = calendar.dateComponents([.hour, .minute], from: parsed)
        return calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: Date())
    }

    /// 指定した日付に "HH:mm" を適用した Date を返す（テンプレから勤務作成用）
    static func applyingTime(_ time: String, to date: Date, calendar: Calendar = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsed = formatter.date(from: time) else { return nil }
        let comps = calendar.dateComponents([.hour, .minute], from: parsed)
        return calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: date)
    }

    /// この日付が含まれる月の開始日 0:00
    func startOfMonth(in calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }

    /// この日付が含まれる月の最終日の翌日 0:00（月範囲の end として使用）
    func endOfMonth(in calendar: Calendar = .current) -> Date {
        guard let next = calendar.date(byAdding: .month, value: 1, to: startOfMonth(in: calendar)) else {
            return self
        }
        return next
    }

    /// この日付が含まれる月の全日（1日〜最終日）の startOfDay の配列
    func daysInMonth(in calendar: Calendar = .current) -> [Date] {
        let start = startOfMonth(in: calendar)
        let end = endOfMonth(in: calendar)
        var dates: [Date] = []
        var current = start
        while current < end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }
}

