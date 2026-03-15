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

    /// このシフトで稼げる合計金額。時給は 時間×単価、固定給はそのまま。
    func totalEarnings(hourlyRates: [HourlyRate], payRates: [PayRate]) -> Decimal? {
        let durationHours: Decimal = {
            let sec = endAt.timeIntervalSince(startAt)
            return Decimal(sec) / 3600
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
