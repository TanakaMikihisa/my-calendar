import SwiftUI

/// 当日の天気を1時間単位で横スクロール表示（予定は表示しない）
struct WeatherTimelineView: View {
    var dayStart: Date
    var weather: Weather?
    var hourlyWeather: [HourlyWeatherItem]

    private let hoursCount = 24
    private let cellWidth: CGFloat = 72
    private let cellHeight: CGFloat = 88

    private var currentHourForToday: Int? {
        let now = Date()
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        guard now >= dayStart, now < dayEnd else { return nil }
        return Calendar.current.component(.hour, from: now)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(0..<hoursCount, id: \.self) { index in
                        hourCell(hour: index, isCurrentHour: index == currentHourForToday)
                            .frame(width: cellWidth, height: cellHeight)
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onAppear {
                if let hour = currentHourForToday {
                    proxy.scrollTo(hour, anchor: .center)
                }
            }
        }
    }

    private func hourCell(hour: Int, isCurrentHour: Bool) -> some View {
        let item = hourItem(hour: hour)
        return VStack(spacing: 6) {
            Text(timeLabel(hour: hour))
                .font(.caption2)
                .foregroundStyle(isCurrentHour ? .primary : .secondary)
                .fontWeight(isCurrentHour ? .semibold : .regular)
            ColoredWeatherSymbolView(symbolName: item.symbol, fontSize: 24)
                .frame(height: 24)
            Text(item.temp)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text(item.precip)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if isCurrentHour {
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(height: 4)
                    .cornerRadius(3)
                    .offset(y: 10)
                    .padding(.horizontal, 5)
            }
        }
    }

    private func hourItem(hour: Int) -> (symbol: String, temp: String, precip: String) {
        let useHourly = hourlyWeather.count >= 24
        if useHourly, hour < hourlyWeather.count {
            let h = hourlyWeather[hour]
            return (
                h.symbolName,
                h.temperatureCelsius.map { "\(Int(round($0)))℃" } ?? "—",
                h.precipitationChance.map { "\(Int(round($0 * 100)))%" } ?? "—"
            )
        }
        if let weather {
            return (
                weather.symbolName,
                weather.temperatureCelsius.map { "\(Int(round($0)))℃" } ?? "—",
                weather.precipitationChance.map { "\(Int(round($0 * 100)))%" } ?? "—"
            )
        }
        return ("cloud", "—", "—")
    }

    private func timeLabel(hour: Int) -> String {
        "\(hour):00"
    }

}
