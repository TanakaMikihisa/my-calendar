import SwiftUI

// MARK: - 天気シンボル用色（メイン・タイムラインで共通）

extension String {
    /// 天気 SF Symbol 名からマルチカラー用の色を返す。(primary, secondary)。secondary が nil のときは単色。
    var weatherSymbolColors: (primary: Color, secondary: Color?) {
        WeatherSymbolStyle.colors(for: self)
    }
}

enum WeatherSymbolStyle {
    static let sun = Color(red: 1, green: 0.65, blue: 0.1)
    static let moon = Color(red: 0.45, green: 0.45, blue: 0.85)
    static let cloud = Color(red: 0.5, green: 0.55, blue: 0.6)
    static let rain = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let snow = Color(red: 0.55, green: 0.78, blue: 0.98)
    static let bolt = Color(red: 0.65, green: 0.4, blue: 0.95)
    static let fog = Color(red: 0.6, green: 0.62, blue: 0.65)
    static let hail = Color(red: 0.6, green: 0.72, blue: 0.95)
    static let wind = Color(red: 0.5, green: 0.52, blue: 0.55)

    /// 第1層・第2層の色。SF Symbol は第1層が雲ベースのため cloud を primary に。
    static func colors(for symbolName: String) -> (primary: Color, secondary: Color?) {
        let s = symbolName.lowercased()

        if s.contains("cloud") && s.contains("sun") && s.contains("rain") {
            return (cloud, rain)
        }
        if s.contains("cloud") && s.contains("sun") && s.contains("bolt") {
            return (cloud, bolt)
        }
        if s.contains("cloud") && s.contains("moon") && s.contains("bolt") {
            return (cloud, bolt)
        }
        if s.contains("cloud") && s.contains("sun") {
            return (cloud, sun)
        }
        if s.contains("cloud") && s.contains("moon") {
            return (cloud, moon)
        }
        if s.contains("cloud") && s.contains("rain") {
            return (cloud, rain)
        }
        if s.contains("cloud") && s.contains("snow") {
            return (cloud, snow)
        }
        if s.contains("cloud") && s.contains("bolt") {
            return (cloud, bolt)
        }
        if s.contains("cloud") && s.contains("fog") {
            return (cloud, fog)
        }
        if s.contains("wind") && s.contains("snow") {
            return (wind, snow)
        }

        if s.contains("sun") { return (sun, nil) }
        if s.contains("moon") { return (moon, nil) }
        if s.contains("rain") || s.contains("drizzle") { return (rain, nil) }
        if s.contains("snow") || s.contains("sleet") || s.contains("flurries") { return (snow, nil) }
        if s.contains("snowflake") { return (snow, nil) }
        if s.contains("bolt") || s.contains("thunder") { return (bolt, nil) }
        if s.contains("fog") || s.contains("haze") || s.contains("mist") { return (fog, nil) }
        if s.contains("hail") { return (hail, nil) }
        if s.contains("wind") || s.contains("hurricane") || s.contains("tornado") { return (wind, nil) }
        if s.contains("cloud") { return (cloud, nil) }

        return (Color.secondary, nil)
    }
}

// MARK: - 色付き天気シンボル View（メイン・タイムラインで共通利用）

struct ColoredWeatherSymbolView: View {
    var symbolName: String
    var fontSize: CGFloat = 24

    var body: some View {
        let colors = symbolName.weatherSymbolColors
        Group {
            if let secondary = colors.secondary {
                Image(systemName: symbolName)
                    .font(.system(size: fontSize))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(colors.primary, secondary)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: fontSize))
                    .foregroundStyle(colors.primary)
            }
        }
    }
}
