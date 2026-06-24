
// Georeferenziazione + notifica locale

import CoreLocation
import UserNotifications

// MARK: - Geofence Service

actor GeofenceService: NSObject {
    private let manager = CLLocationManager()
    static let regionIdentifier = "com.app.poi.home"

    override init() {
        super.init()
        manager.delegate = self
    }

    func addRegion(center: CLLocationCoordinate2D, radius: CLLocationDistance = 100) {
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: Self.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    func removeAllRegions() {
        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
    }
}

extension GeofenceService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { await Self.scheduleNotification(title: "Sei arrivato!", body: "Benvenuto nella zona monitorata.") }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { await Self.scheduleNotification(title: "Hai lasciato la zona", body: "Arrivederci!") }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                      monitoringDidFailFor region: CLRegion?,
                                      withError error: Error) {
        print("Geofencing fallito: \(error.localizedDescription)")
    }

    private static func scheduleNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // consegna immediata
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}