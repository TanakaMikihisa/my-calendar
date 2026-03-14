import Foundation
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit
#endif

/// WeatherKit を使う天気取得。iOS 16+ かつ App に WeatherKit  capability が必要
final class WeatherKitWeatherRepository {
    #if canImport(WeatherKit)
    private let service = WeatherService.shared
    #endif

    init() {}

    func fetchWeather(for date: Date, location: CLLocation) async throws -> Weather? {
        #if canImport(WeatherKit)
        let weather = try await service.weather(for: location)
        let calendar = Calendar.current
        guard let day = weather.dailyForecast.forecast.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let tempCelsius: Double? = {
            let high = day.highTemperature.converted(to: .celsius).value
            let low = day.lowTemperature.converted(to: .celsius).value
            return (high + low) / 2
        }()
        let precipChance: Double? = day.precipitationChance
        return Weather(
            symbolName: day.symbolName,
            temperatureCelsius: tempCelsius,
            precipitationChance: precipChance
        )
        #else
        return nil
        #endif
    }

    /// 当日の天気と、当日分の時間別天気（0〜23時）を取得
    func fetchTodayWeatherWithHourly(location: CLLocation) async throws -> (Weather?, [HourlyWeatherItem]) {
        #if canImport(WeatherKit)
        let weather = try await service.weather(for: location)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let day = weather.dailyForecast.forecast.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) else {
            return (nil, [])
        }
        let daily = Weather(
            symbolName: day.symbolName,
            temperatureCelsius: (day.highTemperature.converted(to: .celsius).value + day.lowTemperature.converted(to: .celsius).value) / 2,
            precipitationChance: day.precipitationChance
        )

        let todayHourly = weather.hourlyForecast.forecast
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
        let byHour: [Int: (String, Double, Double)] = Dictionary(
            uniqueKeysWithValues: todayHourly.map { h in
                (calendar.component(.hour, from: h.date), (
                    h.symbolName,
                    h.temperature.converted(to: .celsius).value,
                    h.precipitationChance
                ))
            }
        )
        let hourly: [HourlyWeatherItem] = (0..<24).map { hour in
            if let t = byHour[hour] {
                return HourlyWeatherItem(hour: hour, symbolName: t.0, temperatureCelsius: t.1, precipitationChance: t.2)
            }
            return HourlyWeatherItem(
                hour: hour,
                symbolName: daily.symbolName,
                temperatureCelsius: daily.temperatureCelsius,
                precipitationChance: daily.precipitationChance
            )
        }
        return (daily, hourly)
        #else
        return (nil, [])
        #endif
    }
}
