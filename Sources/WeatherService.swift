import Foundation

enum WeatherError: LocalizedError, Equatable {
    case placeNotFound
    case invalidURL
    case network(String)
    case server(Int)
    case invalidData
    case cancelled

    var errorDescription: String? {
        switch self {
        case .placeNotFound:
            return "Không tìm thấy địa điểm. Hãy thử tên thành phố hoặc khu vực khác."
        case .invalidURL:
            return "Địa chỉ dịch vụ thời tiết không hợp lệ."
        case .network(let message):
            return message
        case .server(let code):
            return "Máy chủ thời tiết phản hồi mã HTTP \(code). Hãy thử lại sau."
        case .invalidData:
            return "Dữ liệu dự báo không đầy đủ hoặc không hợp lệ."
        case .cancelled:
            return "Yêu cầu đã được hủy."
        }
    }
}

struct WeatherService {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 25
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }
    }

    private func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var geocodingBase: String {
        infoValue("OpenMeteoGeocodingURL") ?? "https://geocoding-api.open-meteo.com/v1/search"
    }

    private var forecastBase: String {
        infoValue("OpenMeteoAPIBaseURL") ?? "https://api.open-meteo.com/v1/forecast"
    }

    private var apiKey: String? { infoValue("OpenMeteoAPIKey") }

    func searchPlaces(_ query: String, limit: Int = 5) async throws -> [GeoPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = try makeComponents(base: geocodingBase)
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: String(max(1, min(limit, 10)))),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ] + keyItem()

        let data = try await data(from: components)
        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return decoded.results ?? []
    }

    func geocode(_ query: String) async throws -> GeoPlace {
        guard let place = try await searchPlaces(query, limit: 1).first else {
            throw WeatherError.placeNotFound
        }
        return place
    }

    func currentWeather(for place: GeoPlace, units: WeatherUnitSystem = .metric) async throws -> WeatherResult {
        var components = try makeComponents(base: forecastBase)
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.6f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", place.longitude)),
            URLQueryItem(name: "current", value: [
                "temperature_2m", "relative_humidity_2m", "apparent_temperature",
                "precipitation", "rain", "weather_code", "is_day", "wind_speed_10m",
                "surface_pressure", "uv_index"
            ].joined(separator: ",")),
            URLQueryItem(name: "hourly", value: [
                "temperature_2m", "precipitation_probability", "precipitation", "weather_code", "uv_index"
            ].joined(separator: ",")),
            URLQueryItem(name: "daily", value: [
                "temperature_2m_max", "temperature_2m_min", "precipitation_probability_max",
                "precipitation_sum", "weather_code", "sunrise", "sunset", "uv_index_max", "wind_speed_10m_max"
            ].joined(separator: ",")),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "forecast_hours", value: "30"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: units.temperatureUnit),
            URLQueryItem(name: "wind_speed_unit", value: units.windUnit),
            URLQueryItem(name: "precipitation_unit", value: units.precipitationUnit)
        ] + keyItem()

        let data = try await data(from: components)
        let decoded: ForecastResponse
        do {
            decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
        } catch {
            throw WeatherError.invalidData
        }

        let timeZone = decoded.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        let hourCount = [
            decoded.hourly.time.count,
            decoded.hourly.temperature.count,
            decoded.hourly.precipitationProbability.count,
            decoded.hourly.precipitation.count,
            decoded.hourly.weatherCode.count,
            decoded.hourly.uvIndex.count
        ].min() ?? 0

        var hours: [HourForecast] = []
        hours.reserveCapacity(min(hourCount, 24))
        for index in 0..<hourCount {
            guard let date = parseLocalDate(decoded.hourly.time[index], timeZone: timeZone) else { continue }
            if date < now.addingTimeInterval(-3600) { continue }
            let localHour = calendar.dateComponents(in: timeZone, from: date).hour ?? 12
            hours.append(.init(
                id: decoded.hourly.time[index],
                date: date,
                temperature: decoded.hourly.temperature[index],
                precipitationProbability: decoded.hourly.precipitationProbability[index],
                precipitation: decoded.hourly.precipitation[index],
                weatherCode: decoded.hourly.weatherCode[index],
                uvIndex: decoded.hourly.uvIndex[index],
                isDay: (6..<18).contains(localHour)
            ))
            if hours.count == 24 { break }
        }

        let dayCount = [
            decoded.daily.time.count,
            decoded.daily.temperatureMax.count,
            decoded.daily.temperatureMin.count,
            decoded.daily.precipitationProbability.count,
            decoded.daily.precipitationSum.count,
            decoded.daily.weatherCode.count,
            decoded.daily.sunrise.count,
            decoded.daily.sunset.count,
            decoded.daily.uvIndexMax.count,
            decoded.daily.windSpeedMax.count
        ].min() ?? 0

        var days: [DayForecast] = []
        days.reserveCapacity(dayCount)
        for index in 0..<dayCount {
            guard let date = parseLocalDate(decoded.daily.time[index], timeZone: timeZone) else { continue }
            days.append(.init(
                id: decoded.daily.time[index],
                date: date,
                maxTemperature: decoded.daily.temperatureMax[index],
                minTemperature: decoded.daily.temperatureMin[index],
                precipitationProbability: decoded.daily.precipitationProbability[index],
                precipitationSum: decoded.daily.precipitationSum[index],
                weatherCode: decoded.daily.weatherCode[index],
                sunrise: parseLocalDate(decoded.daily.sunrise[index], timeZone: timeZone),
                sunset: parseLocalDate(decoded.daily.sunset[index], timeZone: timeZone),
                uvIndexMax: decoded.daily.uvIndexMax[index],
                windSpeedMax: decoded.daily.windSpeedMax[index]
            ))
        }

        guard !hours.isEmpty, !days.isEmpty else { throw WeatherError.invalidData }
        return WeatherResult(
            place: place,
            current: decoded.current,
            units: decoded.currentUnits,
            hourly: hours,
            daily: days,
            timezoneID: decoded.timezone,
            fetchedAt: Date()
        )
    }

    func weather(for query: String, units: WeatherUnitSystem = .metric) async throws -> WeatherResult {
        try await currentWeather(for: geocode(query), units: units)
    }

    private func makeComponents(base: String) throws -> URLComponents {
        guard let components = URLComponents(string: base) else { throw WeatherError.invalidURL }
        return components
    }

    private func keyItem() -> [URLQueryItem] {
        guard let key = apiKey else { return [] }
        return [URLQueryItem(name: "apikey", value: key)]
    }

    private func data(from components: URLComponents) async throws -> Data {
        guard let url = components.url else { throw WeatherError.invalidURL }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw WeatherError.network("Phản hồi mạng không hợp lệ.") }
            guard (200..<300).contains(http.statusCode) else { throw WeatherError.server(http.statusCode) }
            return data
        } catch is CancellationError {
            throw WeatherError.cancelled
        } catch let error as WeatherError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw WeatherError.cancelled }
            let message: String
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                message = "Không có kết nối Internet. Hãy kiểm tra mạng rồi thử lại."
            case .timedOut:
                message = "Kết nối quá thời gian chờ. Hãy thử lại."
            default:
                message = "Không thể kết nối tới dịch vụ thời tiết."
            }
            throw WeatherError.network(message)
        } catch {
            throw WeatherError.network("Đã xảy ra lỗi mạng. Hãy thử lại.")
        }
    }

    private func parseLocalDate(_ value: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = value.contains("T") && value.count > 16 ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
