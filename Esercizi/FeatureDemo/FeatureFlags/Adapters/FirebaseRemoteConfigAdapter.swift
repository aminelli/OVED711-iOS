//
//  FirebaseRemoteConfigAdapter.swift
//  FeatureDemo
//
//  Thin Adapter Layer per Firebase Remote Config.
//
//  PRINCIPIO DI PROGETTAZIONE — Thin Adapter:
//  L'adapter ha la responsabilità MINIMA: tradurre le chiamate del protocollo
//  `FeatureFlagProvider` nelle chiamate specifiche dell'SDK di Firebase.
//  NON contiene logica di business, NON trasforma i dati.
//
//  Questo design garantisce che:
//    - Sostituire Firebase con un altro sistema richiede solo un nuovo adapter
//    - Il resto dell'app non sa (né deve sapere) che si usa Firebase
//    - Il testing è possibile senza Firebase tramite dependency injection
//
//  AGGIUNGERE FIREBASE AL PROGETTO (produzione):
//  1. File → Add Package Dependencies → https://github.com/firebase/firebase-ios-sdk
//  2. Selezionare "FirebaseRemoteConfig" come target
//  3. Rimuovere il blocco "Simulazione SDK" qui sotto
//  4. Sostituire `import FirebaseRemoteConfig` in testa al file
//  5. Rimuovere la classe `MockFirebaseRemoteConfig` e `MockConfigValue`
//
//  COLD START CON FIREBASE:
//  Firebase Remote Config usa una cache locale con scadenza configurabile.
//  Al primo avvio senza cache, il fetch richiede un round-trip di rete (~200-500ms).
//  Nel frattempo, `FeatureFlagService` usa i valori di fallback (vedi cold start problem).

import Foundation

// MARK: - Simulazione SDK Firebase Remote Config
// ⚠️  SOLO PER DEMO — In produzione: `import FirebaseRemoteConfig` e rimuovere questo blocco.

/// Simula la classe `RemoteConfig` di Firebase SDK.
/// In produzione: rimuovere e usare `RemoteConfig.remoteConfig()`.
fileprivate final class MockFirebaseRemoteConfig: @unchecked Sendable {

    static let shared = MockFirebaseRemoteConfig()

    /// Valori di configurazione simulati (in produzione questi arrivano dai server Firebase).
    private var values: [String: Any] = [
        FeatureFlagKey.rt_newOnboarding.rawValue:            false,
        FeatureFlagKey.rt_redesignedHome.rawValue:           false,
        FeatureFlagKey.et_checkoutButtonColor.rawValue:      true,  // variante B attiva al 50%
        FeatureFlagKey.et_recommendationAlgorithm.rawValue:  false,
        FeatureFlagKey.ot_maintenanceMode.rawValue:          false,
        FeatureFlagKey.ot_analyticsEnabled.rawValue:         true,
        FeatureFlagKey.pt_premiumContent.rawValue:           false,
        FeatureFlagKey.pt_advancedExport.rawValue:           false
    ]

    /// Simula `fetch(withExpirationDuration:)` di Firebase.
    /// In produzione: esegue una chiamata HTTP ai server di Firebase.
    func fetch(withExpirationDuration duration: TimeInterval) async throws {
        // Simula la latenza di rete tipica di Firebase Remote Config
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        // In produzione: la chiamata potrebbe fallire per problemi di rete
        // Firebase lancia un'eccezione `RemoteConfigError` in quel caso
    }

    /// Simula `activate()` di Firebase.
    /// In produzione: rende attivi i valori fetchati sostituendo quelli in cache.
    @discardableResult
    func activate() async throws -> Bool {
        // In produzione: restituisce `true` se i valori sono cambiati rispetto alla cache
        return true
    }

    /// Simula `configValue(forKey:)` di Firebase.
    func configValue(forKey key: String) -> MockConfigValue {
        MockConfigValue(rawValue: values[key])
    }

    private init() {}
}

/// Simula `RemoteConfigValue` di Firebase SDK.
private struct MockConfigValue: @unchecked Sendable {
    let rawValue: Any?

    // In produzione: `RemoteConfigValue.boolValue`, `.stringValue`, `.numberValue`
    var boolValue: Bool       { rawValue as? Bool ?? false }
    var stringValue: String   { rawValue as? String ?? "" }
    var numberValue: NSNumber { NSNumber(value: rawValue as? Double ?? 0) }
}

// MARK: - FirebaseRemoteConfigAdapter

/// Adapter che implementa `FeatureFlagProvider` usando Firebase Remote Config.
///
/// Thin layer: traduce le chiamate del protocollo in chiamate SDK Firebase.
/// Nessuna logica di business. Nessuna trasformazione dei dati.
final class FirebaseRemoteConfigAdapter: FeatureFlagProvider, @unchecked Sendable {

    // MARK: - Proprietà

    /// Istanza di RemoteConfig.
    /// In produzione: `private let remoteConfig: RemoteConfig`
    /// Per la demo: usa il mock.
    private let remoteConfig: MockFirebaseRemoteConfig

    // MARK: - Inizializzazione

    /// Inizializza l'adapter con l'istanza RemoteConfig di default.
    /// Usato da `AppDependencies` e dal codice app.
    init() {
        self.remoteConfig = .shared
    }

    /// Inizializza l'adapter con un'istanza RemoteConfig iniettata.
    /// L'iniezione dell'istanza tramite il costruttore permette il testing con un mock.
    fileprivate init(remoteConfig: MockFirebaseRemoteConfig) {
        self.remoteConfig = remoteConfig
    }

    // MARK: - FeatureFlagProvider

    func boolValue(for key: FeatureFlagKey) -> Bool {
        // In produzione: `remoteConfig[key.rawValue].boolValue`
        let value = remoteConfig.configValue(forKey: key.rawValue).boolValue
        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[Firebase] boolValue(\(key.rawValue)) = \(value)")
        }
        return value
    }

    func stringValue(for key: FeatureFlagKey) -> String? {
        // In produzione: `remoteConfig[key.rawValue].stringValue`
        let value = remoteConfig.configValue(forKey: key.rawValue).stringValue
        return value.isEmpty ? nil : value
    }

    func doubleValue(for key: FeatureFlagKey) -> Double? {
        // In produzione: `remoteConfig[key.rawValue].numberValue.doubleValue`
        let value = remoteConfig.configValue(forKey: key.rawValue).numberValue.doubleValue
        return value == 0 ? nil : value
    }

    /// Esegue fetch + activate di Firebase Remote Config.
    ///
    /// Il parametro `withExpirationDuration` controlla quanti secondi Firebase
    /// usa la cache locale prima di fare una nuova richiesta ai server.
    /// Valore consigliato: 3600 secondi (1 ora) in produzione.
    /// Durante lo sviluppo usare 0 per ottenere sempre dati freschi.
    func fetch() async throws {
        let cacheDuration: TimeInterval = CompileTimeFlags.isDebugBuild ? 0 : 3600

        // Step 1: Recupera i valori aggiornati dai server Firebase
        try await remoteConfig.fetch(withExpirationDuration: cacheDuration)

        // Step 2: Rendi attivi i nuovi valori fetchati
        // In produzione: `remoteConfig.activate()`
        try await remoteConfig.activate()

        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[Firebase] ✅ Remote Config fetchato e attivato con successo")
        }
    }
}
