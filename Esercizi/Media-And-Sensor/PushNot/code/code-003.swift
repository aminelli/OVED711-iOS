// Silent push con in più agg. dati

// In AppDelegate: gestione content-available silent push
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    // Payload: { "aps": { "content-available": 1 }, "type": "data_sync" }
    guard let type = userInfo["type"] as? String, type == "data_sync" else {
        completionHandler(.noData)
        return
    }

    Task {
        do {
            // Sincronizza dati in background
            try await DataSyncService.shared.sync()
            completionHandler(.newData)
        } catch {
            completionHandler(.failed)
        }
    }
}

// Placeholder service
actor DataSyncService {
    static let shared = DataSyncService()
    func sync() async throws { /* ... */ }
}