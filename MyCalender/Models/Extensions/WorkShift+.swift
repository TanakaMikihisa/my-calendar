import Foundation

extension WorkShift {
    /// 表示用タイトル。payRateId があれば会社名、なければ "勤務"
    func displayTitle(payRates: [PayRate]) -> String {
        guard let id = payRateId, let rate = payRates.first(where: { $0.id == id }) else {
            return "勤務"
        }
        return rate.title
    }
}
