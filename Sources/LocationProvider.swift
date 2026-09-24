import Foundation
import CoreLocation

@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum LocationError: LocalizedError {
        case denied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Quyền vị trí đang tắt. Vào Cài đặt → Quyền riêng tư & Bảo mật → Dịch vụ định vị để bật."
            case .unavailable:
                return "Không xác định được vị trí hiện tại. Hãy thử lại hoặc tìm thành phố thủ công."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func currentLocation() async throws -> CLLocation {
        if let continuation {
            continuation.resume(throwing: CancellationError())
            self.continuation = nil
        }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        case .notDetermined:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestLocation()
            }
        @unknown default:
            throw LocationError.unavailable
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.denied)
            continuation = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let continuation else { return }
        continuation.resume(returning: location)
        self.continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation else { return }
        continuation.resume(throwing: LocationError.unavailable)
        self.continuation = nil
    }
}
