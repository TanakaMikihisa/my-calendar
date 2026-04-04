import Foundation

/// 内閣府「国民の祝日・休日」CSV（Shift-JIS）を取得し、日付集合に変換する
enum JapaneseHolidayCSVFetcher {
    /// 内閣府の祝日CSV
    static let csvURL = URL(string: "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv")!

    private static var shiftJISEncoding: String.Encoding {
        String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
            )
        )
    }

    /// 各祝日を `Calendar.current` のその日 0:00 に正規化した集合（名称は利用しない）
    static func fetchHolidayStartOfDays() async throws -> Set<Date> {
        let (data, response) = try await URLSession.shared.data(from: csvURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let csvString = String(data: data, encoding: shiftJISEncoding) else {
            throw URLError(.cannotDecodeContentData)
        }

        var tokyoCal = Calendar(identifier: .gregorian)
        tokyoCal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = tokyoCal
        dateFormatter.dateFormat = "yyyy/M/d"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = tokyoCal.timeZone

        let localCal = Calendar.current
        var result: Set<Date> = []
        let rows = csvString.components(separatedBy: .newlines)

        for row in rows.dropFirst() {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let columns = trimmed.components(separatedBy: ",")
            guard columns.count >= 2 else { continue }
            let dateString = columns[0].trimmingCharacters(in: .whitespaces)
            guard let parsed = dateFormatter.date(from: dateString) else { continue }
            let ymd = tokyoCal.dateComponents([.year, .month, .day], from: parsed)
            guard let y = ymd.year, let m = ymd.month, let d = ymd.day else { continue }
            guard let dayStart = localCal.date(from: DateComponents(year: y, month: m, day: d)) else { continue }
            result.insert(localCal.startOfDay(for: dayStart))
        }
        return result
    }
}
