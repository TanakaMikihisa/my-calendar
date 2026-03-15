import Foundation

extension HourlyRate {
    /// 表示用ラベル（名前なしなので金額のみ）
    func displayLabel() -> String {
        "¥\(NSDecimalNumber(decimal: amount).stringValue)/時"
    }
}

extension Array where Element == HourlyRate {
    /// ID で時給を解決。見つからなければ nil（変更すると参照元に反映）
    func amount(for id: HourlyRateID?) -> Decimal? {
        guard let id, !id.isEmpty else { return nil }
        return first(where: { $0.id == id })?.amount
    }
}
