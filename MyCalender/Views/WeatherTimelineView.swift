import SwiftUI

/// 当日の天気を1時間単位で表示する時間軸ビュー（予定は表示しない）
struct WeatherTimelineView: View {
    var dayStart: Date
    var weather: Weather?
    var hourlyWeather: [HourlyWeatherItem]

    private let hoursCount = 24
    private let pointsPerBlock: CGFloat = 56
    private var timelineTotalHeight: CGFloat { CGFloat(hoursCount) * pointsPerBlock }
    private var rowHeight: CGFloat { timelineTotalHeight / CGFloat(hoursCount) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                timeRuler
                timeGridLines
                if let weather {
                    weatherRows(weather: weather)
                }
                currentTimeLine
            }
            .frame(height: timelineTotalHeight)
            .padding(.leading, 20)
            .padding(.trailing, 7)
        }
        .padding(.top, 16)
    }

    private var timeRuler: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(0..<hoursCount, id: \.self) { index in
                    Text(timeLabel(hour: index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: pointsPerBlock, alignment: .topLeading)
                }
            }
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .frame(height: timelineTotalHeight)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: timelineTotalHeight)
                .allowsHitTesting(false)
        }
    }

    private var timeGridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<hoursCount, id: \.self) { _ in
                Rectangle()
                    .fill(Color(.systemGray5).opacity(0.6))
                    .frame(height: 1.5)
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: pointsPerBlock - 1)
            }
        }
        .frame(height: timelineTotalHeight)
        .frame(maxWidth: .infinity)
        .padding(.leading, 52)
        .allowsHitTesting(false)
    }

    private func weatherRows(weather: Weather) -> some View {
        let useHourly = hourlyWeather.count >= 24
        return GeometryReader { geometry in
            let w = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(0..<hoursCount, id: \.self) { index in
                    let item: (symbol: String, temp: String, precip: String) = {
                        if useHourly, index < hourlyWeather.count {
                            let h = hourlyWeather[index]
                            return (
                                h.symbolName,
                                h.temperatureCelsius.map { "\(Int(round($0)))℃" } ?? "—",
                                h.precipitationChance.map { "\(Int(round($0 * 100)))%" } ?? "—"
                            )
                        }
                        return (
                            weather.symbolName,
                            weather.temperatureCelsius.map { "\(Int(round($0)))℃" } ?? "—",
                            weather.precipitationChance.map { "\(Int(round($0 * 100)))%" } ?? "—"
                        )
                    }()
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 22)
                        Text(item.temp)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(width: 40, alignment: .leading)
                        Text("\(item.precip)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                    .frame(width: w, height: rowHeight, alignment: .leading)
                    .offset(x: 0, y: CGFloat(index) * rowHeight)
                }
            }
        }
        .padding(.leading, 52)
    }

    private var currentTimeLine: some View {
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        let pointsPerMinute = pointsPerBlock / 60
        return TimelineView(.periodic(from: Date(), by: 60)) { context in
            let now = context.date
            if now >= dayStart && now < dayEnd {
                let minutesFromStart = now.timeIntervalSince(dayStart) / 60
                let y = CGFloat(minutesFromStart) * pointsPerMinute
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .offset(y: y)
                    .padding(.leading, 52)
            }
        }
        .allowsHitTesting(false)
    }

    private func timeLabel(hour: Int) -> String {
        "\(hour):00"
    }
}
