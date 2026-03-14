import Foundation

/// その日の天気表示用（シンボル名・気温・降水確率）
struct Weather: Sendable {
    /// SF Symbol 名（例: sun.max, cloud.rain）
    var symbolName: String
    /// 気温（℃）。取得できない場合は nil
    var temperatureCelsius: Double?
    /// 降水確率 0.0〜1.0。取得できない場合は nil
    var precipitationChance: Double?
}

/// 1時間単位の天気（時間軸表示用）
struct HourlyWeatherItem: Sendable {
    /// 0〜23（その日の何時か）
    var hour: Int
    var symbolName: String
    var temperatureCelsius: Double?
    var precipitationChance: Double?
}
