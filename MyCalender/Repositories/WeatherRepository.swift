import Foundation
import CoreLocation

// MARK: - Protocol

protocol WeatherRepositoryProtocol {
    /// 指定日の天気を取得。位置は実装側で取得するかデフォルト地域を使用
    func fetchWeather(for date: Date) async throws -> Weather?
    /// 当日の天気と24時間分の時間別天気を取得（アプリ起動時など1回だけ呼ぶ想定）
    func fetchTodayWeatherWithHourly() async throws -> (Weather?, [HourlyWeatherItem])
}

// MARK: - 位置情報＋WeatherKit

final class DefaultWeatherRepository: WeatherRepositoryProtocol {
    private let locationRepository: LocationRepositoryProtocol
    private let weatherKitRepository: WeatherKitWeatherRepository
    private static let defaultLocation = CLLocation(latitude: 35.68, longitude: 139.69)

    /// locationRepository は @MainActor のため、呼び出し元（例: View）で生成して渡す
    init(
        locationRepository: LocationRepositoryProtocol,
        weatherKitRepository: WeatherKitWeatherRepository = WeatherKitWeatherRepository()
    ) {
        self.locationRepository = locationRepository
        self.weatherKitRepository = weatherKitRepository
    }

    func fetchWeather(for date: Date) async throws -> Weather? {
        let location = await locationRepository.currentLocation() ?? Self.defaultLocation
        return try await weatherKitRepository.fetchWeather(for: date, location: location)
    }

    func fetchTodayWeatherWithHourly() async throws -> (Weather?, [HourlyWeatherItem]) {
        let location = await locationRepository.currentLocation() ?? Self.defaultLocation
        return try await weatherKitRepository.fetchTodayWeatherWithHourly(location: location)
    }
}
