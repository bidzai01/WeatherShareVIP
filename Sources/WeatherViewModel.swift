import Foundation
import Observation
import CoreLocation

@MainActor
@Observable
final class WeatherViewModel {
    enum State {
        case idle
        case loading
        case loaded(WeatherResult)
        case failed(String)
    }

    var query = ""
    var suggestions: [GeoPlace] = []
    var unitSystem: WeatherUnitSystem {
        didSet { UserDefaults.standard.set(unitSystem.rawValue, forKey: Self.unitKey) }
    }
    private(set) var state: State = .idle
    private(set) var isSearching = false

    private static let unitKey = "weather.unitSystem"
    private let service: WeatherService
    private let locationProvider = LocationProvider()
    private var lastPlace: GeoPlace?
    private var requestTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?

    init(service: WeatherService = WeatherService()) {
        self.service = service
        self.unitSystem = WeatherUnitSystem(rawValue: UserDefaults.standard.string(forKey: Self.unitKey) ?? "metric") ?? .metric
    }

    var result: WeatherResult? {
        if case let .loaded(result) = state { return result }
        return nil
    }

    var errorMessage: String? {
        if case let .failed(message) = state { return message }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func updateSuggestions(for text: String) {
        suggestionTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }

        suggestionTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                suggestions = try await service.searchPlaces(trimmed)
            } catch {
                if !Task.isCancelled { suggestions = [] }
            }
        }
    }

    func select(_ place: GeoPlace) async {
        query = place.name
        suggestions = []
        await load(place: place)
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        suggestions = []
        await run { [service, unitSystem] in
            try await service.weather(for: trimmed, units: unitSystem)
        } placeHandler: { [weak self] result in
            self?.lastPlace = result.place
        }
    }

    func load(place: GeoPlace) async {
        await run { [service, unitSystem] in
            try await service.currentWeather(for: place, units: unitSystem)
        } placeHandler: { [weak self] result in
            self?.lastPlace = result.place
        }
    }

    func reload() async {
        if let place = lastPlace {
            await load(place: place)
        } else {
            await locateMe()
        }
    }

    func locateMe() async {
        await run { [service, unitSystem, locationProvider] in
            let location = try await locationProvider.currentLocation()
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let name = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.name ?? "Vị trí hiện tại"
            let admin = placemark?.administrativeArea.flatMap { $0 == name ? nil : $0 }
            let place = GeoPlace(
                id: -1,
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                country: placemark?.country,
                admin1: admin,
                timezone: TimeZone.current.identifier
            )
            return try await service.currentWeather(for: place, units: unitSystem)
        } placeHandler: { [weak self] result in
            self?.lastPlace = result.place
            self?.query = result.place.name
        }
    }

    func changeUnits(_ units: WeatherUnitSystem) async {
        guard unitSystem != units else { return }
        unitSystem = units
        guard let place = lastPlace else { return }
        await load(place: place)
    }

    func cancel() {
        requestTask?.cancel()
        suggestionTask?.cancel()
        isSearching = false
    }

    deinit {
        requestTask?.cancel()
        suggestionTask?.cancel()
    }

    private func run(
        operation: @escaping () async throws -> WeatherResult,
        placeHandler: @escaping (WeatherResult) -> Void
    ) async {
        requestTask?.cancel()
        state = .loading
        let task = Task { try await operation() }
        requestTask = task
        do {
            let result = try await task.value
            guard !Task.isCancelled else { return }
            placeHandler(result)
            state = .loaded(result)
        } catch is CancellationError {
            if case .loading = state { state = .idle }
        } catch let error as WeatherError {
            if error == .cancelled { return }
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
