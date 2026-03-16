import Foundation

extension ShiftTemplate {
    /// このテンプレで稼げる給与の表示用文字列。時給なら（勤務時間−休憩）×単価、固定給ならそのまま。計算できない場合は nil。
    func earningsDisplay(hourlyRates: [HourlyRate]) -> String? {
        let calendar = Calendar.current
        guard let startDate = Date.fromTimeString(startTime, calendar: calendar),
              let endDate = Date.fromTimeString(endTime, calendar: calendar) else { return nil }
        var durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        if durationMinutes <= 0 { durationMinutes += 24 * 60 }
        let workMinutes = max(0, durationMinutes - breakMinutes)
        let hours = Decimal(workMinutes) / 60

        switch payType {
        case .hourly:
            guard let id = hourlyRateId,
                  let rate = hourlyRates.first(where: { $0.id == id }) else { return nil }
            let amount = rate.amount * hours
            return "¥\(NSDecimalNumber(decimal: amount).stringValue)"
        case .fixed:
            guard let fixed = fixedPay else { return nil }
            return "¥\(NSDecimalNumber(decimal: fixed).stringValue)"
        }
    }
}
