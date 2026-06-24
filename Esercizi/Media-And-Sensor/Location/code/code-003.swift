// Reverse geocoding async

import CoreLocation

extension CLGeocoder {
    /// Converte `CLLocation` in indirizzo leggibile (reverse geocoding)
    func reverseGeocode(_ location: CLLocation) async throws -> String {
        let placemarks = try await reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw CoordinateError.noPlacemark
        }
        let components = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { $0 }
        return components.joined(separator: ", ")
    }
}

enum CoordinateError: Error { case noPlacemark }

// MARK: - Uso in ViewModel

@Observable @MainActor
final class LocationViewModel {
    var address: String = ""
    var currentCoordinate: CLLocationCoordinate2D?
    private let service = LocationService()
    private let geocoder = CLGeocoder()

    func start() async {
        await service.requestPermission()
        await service.startTracking()

        Task {
            for await location in await service.locationStream {
                self.currentCoordinate = location.coordinate
                if let addr = try? await geocoder.reverseGeocode(location) {
                    self.address = addr
                }
            }
        }
    }
}