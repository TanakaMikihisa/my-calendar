import Foundation

extension String {
    /// 全角数字（０-９）を半角（0-9）に変換した文字列を返す
    func applyingFullWidthToHalfWidthDigits() -> String {
        let fullWidth = "０１２３４５６７８９"
        let halfWidth = "0123456789"
        var result = self
        for (f, h) in zip(fullWidth, halfWidth) {
            result = result.replacingOccurrences(of: String(f), with: String(h))
        }
        return result
    }

    /// スペース除去・全角→半角ののち "H:mm-H:mm" または "H:mm〜H:mm" を探し、(開始時, 開始分, 終了時, 終了分) を返す。見つからなければ nil
    func parsedTimeRange() -> (startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)? {
        let normalized = self
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .applyingFullWidthToHalfWidthDigits()
        guard !normalized.isEmpty else { return nil }
        let pattern = #"(\d{1,2}):(\d{1,2})[-〜](\d{1,2}):(\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              match.numberOfRanges >= 5,
              let r1 = Range(match.range(at: 1), in: normalized),
              let r2 = Range(match.range(at: 2), in: normalized),
              let r3 = Range(match.range(at: 3), in: normalized),
              let r4 = Range(match.range(at: 4), in: normalized),
              let h1 = Int(normalized[r1]), let m1 = Int(normalized[r2]),
              let h2 = Int(normalized[r3]), let m2 = Int(normalized[r4]),
              (0...23).contains(h1), (0...59).contains(m1),
              (0...23).contains(h2), (0...59).contains(m2) else { return nil }
        return (startHour: h1, startMinute: m1, endHour: h2, endMinute: m2)
    }
}
