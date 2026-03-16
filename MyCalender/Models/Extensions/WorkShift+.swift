import Foundation

extension WorkShift {
    /// 表示用タイトル。時給は PayRate の会社名、固定給は companyName、どちらもなければ "勤務"
    func displayTitle(payRates: [PayRate]) -> String {
        if payType == .hourly, let id = payRateId, let rate = payRates.first(where: { $0.id == id }) {
            return rate.title
        }
        if payType == .fixed, let name = companyName, !name.isEmpty {
            return name
        }
        return "勤務"
    }

    /// このシフトで稼げる合計金額。時給は（勤務時間−休憩）×単価、固定給はそのまま。
    func totalEarnings(hourlyRates: [HourlyRate], payRates: [PayRate]) -> Decimal? {
        let durationHours: Decimal = {
            let totalMinutes = Int(endAt.timeIntervalSince(startAt) / 60)
            let workMinutes = max(0, totalMinutes - breakMinutes)
            return Decimal(workMinutes) / 60
        }()
        switch payType {
        case .hourly:
            if let amount = hourlyRates.amount(for: hourlyRateId) {
                return amount * durationHours
            }
            if let payRateId, let rate = payRates.first(where: { $0.id == payRateId }) {
                return rate.hourlyWage * durationHours
            }
            return nil
        case .fixed:
            return fixedPay
        }
    }
}
