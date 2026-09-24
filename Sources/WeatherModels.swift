import Foundation
import CoreLocation

struct GeocodingResponse: Decodable {
    let results: [GeoPlace]?
}

struct GeoPlace: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, country, admin1, timezone
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        [name, admin1, country].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct ForecastResponse: Decodable {
    let current: CurrentWeather
    let currentUnits: CurrentUnits
    let hourly: HourlyWeather
    let daily: DailyWeather
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case current, hourly, daily, timezone
        case currentUnits = "current_units"
    }
}

struct CurrentWeather: Decodable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let precipitation: Double
    let rain: Double
    let weatherCode: Int
    let isDay: Int
    let surfacePressure: Double
    let uvIndex: Double

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case humidity = "relative_humidity_2m"
        case windSpeed = "wind_speed_10m"
        case precipitation, rain
        case weatherCode = "weather_code"
        case isDay = "is_day"
        case surfacePressure = "surface_pressure"
        case uvIndex = "uv_index"
    }
}

struct CurrentUnits: Decodable {
    let temperature: String
    let windSpeed: String
    let precipitation: String
    let surfacePressure: String
    let uvIndex: String

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case windSpeed = "wind_speed_10m"
        case precipitation
        case surfacePressure = "surface_pressure"
        case uvIndex = "uv_index"
    }
}

struct HourlyWeather: Decodable {
    let time: [String]
    let temperature: [Double]
    let precipitationProbability: [Int]
    let precipitation: [Double]
    let weatherCode: [Int]
    let uvIndex: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case weatherCode = "weather_code"
        case uvIndex = "uv_index"
    }
}

struct DailyWeather: Decodable {
    let time: [String]
    let temperatureMax: [Double]
    let temperatureMin: [Double]
    let precipitationProbability: [Int]
    let precipitationSum: [Double]
    let weatherCode: [Int]
    let sunrise: [String]
    let sunset: [String]
    let uvIndexMax: [Double]
    let windSpeedMax: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationProbability = "precipitation_probability_max"
        case precipitationSum = "precipitation_sum"
        case weatherCode = "weather_code"
        case sunrise, sunset
        case uvIndexMax = "uv_index_max"
        case windSpeedMax = "wind_speed_10m_max"
    }
}

struct WeatherCondition: Hashable {
    let label: String
    let symbol: String

    static func from(code: Int, isDay: Bool) -> WeatherCondition {
        switch code {
        case 0: return .init(label: "Trời quang", symbol: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: return .init(label: "Khá quang", symbol: isDay ? "sun.max.fill" : "moon.fill")
        case 2: return .init(label: "Mây rải rác", symbol: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return .init(label: "Nhiều mây", symbol: "cloud.fill")
        case 45, 48: return .init(label: "Sương mù", symbol: "cloud.fog.fill")
        case 51, 53, 55: return .init(label: "Mưa phùn", symbol: "cloud.drizzle.fill")
        case 56, 57, 66, 67: return .init(label: "Mưa lạnh", symbol: "cloud.sleet.fill")
        case 61, 63, 65: return .init(label: "Mưa", symbol: "cloud.rain.fill")
        case 71, 73, 75, 77: return .init(label: "Tuyết", symbol: "cloud.snow.fill")
        case 80, 81, 82: return .init(label: "Mưa rào", symbol: "cloud.heavyrain.fill")
        case 85, 86: return .init(label: "Mưa tuyết", symbol: "cloud.snow.fill")
        case 95, 96, 99: return .init(label: "Dông", symbol: "cloud.bolt.rain.fill")
        default: return .init(label: "Không xác định", symbol: "questionmark.circle.fill")
        }
    }
}

struct HourForecast: Identifiable, Hashable {
    let id: String
    let date: Date
    let temperature: Double
    let precipitationProbability: Int
    let precipitation: Double
    let weatherCode: Int
    let uvIndex: Double
    let isDay: Bool

    var condition: WeatherCondition {
        WeatherCondition.from(code: weatherCode, isDay: isDay)
    }
}

struct DayForecast: Identifiable, Hashable {
    let id: String
    let date: Date
    let maxTemperature: Double
    let minTemperature: Double
    let precipitationProbability: Int
    let precipitationSum: Double
    let weatherCode: Int
    let sunrise: Date?
    let sunset: Date?
    let uvIndexMax: Double
    let windSpeedMax: Double

    var condition: WeatherCondition {
        WeatherCondition.from(code: weatherCode, isDay: true)
    }
}

struct WeatherResult {
    let place: GeoPlace
    let current: CurrentWeather
    let units: CurrentUnits
    let hourly: [HourForecast]
    let daily: [DayForecast]
    let timezoneID: String?
    let fetchedAt: Date

    var condition: WeatherCondition {
        WeatherCondition.from(code: current.weatherCode, isDay: current.isDay == 1)
    }

    var timeZone: TimeZone {
        timezoneID.flatMap(TimeZone.init(identifier:)) ?? .current
    }
}

enum WeatherUnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var title: String { self == .metric ? "°C / km/h" : "°F / mph" }
    var temperatureUnit: String { self == .metric ? "celsius" : "fahrenheit" }
    var windUnit: String { self == .metric ? "kmh" : "mph" }
    var precipitationUnit: String { self == .metric ? "mm" : "inch" }
}
