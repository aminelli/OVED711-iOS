// LocationService


import CoreLocation
import Foundation

// MARK: - Location Service Actor

actor LocationService: NSObject {
    private let manager = CLLocationManager()
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?

    // Stream pubblico consumabile da ViewModel / View
    let locationStream: AsyncStream<CLLocation>

    override init() {
        var cont: AsyncStream<CLLocation>.Continuation!
        locationStream = AsyncStream(bufferingPolicy: .bufferingNewest(5)) { cont = $0 }
        locationContinuation = cont
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    // MARK: - Autorizzazione

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            break // già autorizzato
        default:
            locationContinuation?.finish()
        }
    }

    // MARK: - Controllo tracking

    func startTracking() {
        guard manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Singola posizione

    func currentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let handler = SingleLocationDelegate { result in
                continuation.resume(with: result)
            }
            let localManager = CLLocationManager()
            localManager.delegate = handler
            localManager.desiredAccuracy = kCLLocationAccuracyBest
            localManager.requestLocation()
            // Mantieni handler e manager vivi
            Task { _ = (handler, localManager) }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                      didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { await self.publish(location: latest) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task {
            await self.handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await self.locationContinuation?.finish() }
    }

    private func publish(location: CLLocation) {
        locationContinuation?.yield(location)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            locationContinuation?.finish()
        }
    }
}

// MARK: - Delegate per singola posizione

private final class SingleLocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<CLLocation, Error>) -> Void

    init(completion: @Sendable @escaping (Result<CLLocation, Error>) -> Void) {
        self.completion = completion
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        manager.delegate = nil
        completion(.success(loc))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.delegate = nil
        completion(.failure(error))
    }
}
