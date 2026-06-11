//
//  LaunchDarklyAdapter.swift
//  FeatureDemo
//
//  Thin Adapter Layer per LaunchDarkly iOS SDK.
//
//  LaunchDarkly è una piattaforma enterprise per feature flag che offre:
//    - Targeting avanzato per utente, segmento, attributi personalizzati
//    - Rollout percentuale granulare
//    - Aggiornamenti in streaming (Server-Sent Events) senza polling
//    - Dashboard di analytics A/B integrata
//    - Audit log e governance dei flag
//
//  DIFFERENZA CHIAVE CON FIREBASE REMOTE CONFIG:
//  LaunchDarkly è orientato al contesto utente: ogni flag viene valutato
//  in base al profilo dell'utente corrente (LDContext), non solo alla configurazione globale.
//  Questo permette targeting preciso (es: "abilita per utenti iOS > 3.2.0 in Italia").
//
//  AGGIUNGERE LAUNCHDARKLY AL PROGETTO (produzione):
//  1. File → Add Package Dependencies → https://github.com/launchdarkly/ios-client-sdk
//  2. Selezionare "LaunchDarkly" come target
//  3. Inizializzare il client all'avvio: `LDClient.start(config: LDConfig(mobileKey: "..."))`
//  4. Sostituire `import LaunchDarkly` e rimuovere i mock qui sotto

import Foundation

// MARK: - Simulazione SDK LaunchDarkly
// ⚠️  SOLO PER DEMO — In produzione: `import LaunchDarkly` e rimuovere questo blocco.

/// Simula `LDContext` di LaunchDarkly SDK.
/// Il context identifica l'utente e i suoi attributi per il targeting dei flag.
struct LDUserContext: Sendable {
    /// Chiave univoca dell'utente (solitamente l'ID utente o un UUID anonimo)
    let key: String
    /// Email dell'utente (opzionale, usata per targeting per email/dominio)
    let email: String?
    /// Indica se l'utente ha un abbonamento premium (attributo personalizzato)
    let isPremium: Bool
    /// Versione dell'app (usata per targeting per versione: es. "abilita solo su >= 2.0")
    let appVersion: String
    /// Paese dell'utente (usato per targeting geografico)
    let country: String

    /// Contesto utente anonimo — usato prima del login.
    // Usa una stringa fissa: `UUID()` è @MainActor in iOS 26.
    static let anonymous = LDUserContext(
        key: "anonymous",
        email: nil,
        isPremium: false,
        appVersion: "unknown",
        country: "unknown"
    )
}

/// Simula il client LaunchDarkly (in produzione: `LDClient`).
fileprivate final class MockLDClient: @unchecked Sendable {

    static let shared = MockLDClient()

    private var context: LDUserContext = .anonymous

    /// Configurazione base dei flag (default globale, senza targeting)
    private var baseFlags: [String: Any] = [
        FeatureFlagKey.rt_newOnboarding.rawValue:            false,
        FeatureFlagKey.rt_redesignedHome.rawValue:           true,  // abilitato nel remoto
        FeatureFlagKey.et_checkoutButtonColor.rawValue:      false,
        FeatureFlagKey.et_recommendationAlgorithm.rawValue:  false,
        FeatureFlagKey.ot_maintenanceMode.rawValue:          false,
        FeatureFlagKey.ot_analyticsEnabled.rawValue:         true,
        FeatureFlagKey.pt_premiumContent.rawValue:           false,
        FeatureFlagKey.pt_advancedExport.rawValue:           false
    ]

    /// Simula `LDClient.identify(context:)`.
    /// In produzione: aggiorna il contesto utente sul server LaunchDarkly
    /// e riceve i flag aggiornati per il nuovo utente.
    func identify(context: LDUserContext) async throws {
        self.context = context

        // Simulazione del targeting basato sugli attributi utente
        if context.isPremium {
            baseFlags[FeatureFlagKey.pt_premiumContent.rawValue] = true
            baseFlags[FeatureFlagKey.pt_advancedExport.rawValue] = true
        }

        // Simula la latenza della chiamata di identify
        try await Task.sleep(for: .milliseconds(100))
    }

    /// Simula `LDClient.boolVariation(forKey:defaultValue:)`.
    func boolVariation(forKey key: String, defaultValue: Bool) -> Bool {
        baseFlags[key] as? Bool ?? defaultValue
    }

    /// Simula `LDClient.stringVariation(forKey:defaultValue:)`.
    func stringVariation(forKey key: String, defaultValue: String) -> String {
        baseFlags[key] as? String ?? defaultValue
    }

    /// Simula `LDClient.doubleVariation(forKey:defaultValue:)`.
    func doubleVariation(forKey key: String, defaultValue: Double) -> Double {
        baseFlags[key] as? Double ?? defaultValue
    }

    private init() {}
}

// MARK: - LaunchDarklyAdapter

/// Adapter che implementa `FeatureFlagProvider` usando LaunchDarkly iOS SDK.
///
/// Thin layer: traduce le chiamate del protocollo nelle chiamate SDK LaunchDarkly.
/// Supporta l'identificazione dell'utente per il targeting personalizzato.
final class LaunchDarklyAdapter: FeatureFlagProvider, @unchecked Sendable {

    // MARK: - Proprietà

    /// Client LaunchDarkly.
    /// In produzione: `LDClient.get()!` (singleton inizializzato nell'AppDelegate)
    private let client: MockLDClient

    /// Contesto utente per il targeting dei flag.
    private let userContext: LDUserContext

    // MARK: - Inizializzazione

    /// Inizializza l'adapter con contesto utente (client di default).
    /// Usato da `AppDependencies` e dal codice app.
    init(userContext: LDUserContext = .anonymous) {
        self.client = .shared
        self.userContext = userContext
    }

    /// Inizializza l'adapter con client e contesto iniettati.
    /// Usato per il testing con mock.
    fileprivate init(client: MockLDClient, userContext: LDUserContext = .anonymous) {
        self.client = client
        self.userContext = userContext
    }

    // MARK: - FeatureFlagProvider

    func boolValue(for key: FeatureFlagKey) -> Bool {
        // In produzione: `LDClient.get()!.boolVariation(forKey: key.rawValue, defaultValue: key.defaultBoolValue)`
        return client.boolVariation(
            forKey: key.rawValue,
            defaultValue: key.defaultBoolValue
        )
    }

    func stringValue(for key: FeatureFlagKey) -> String? {
        // In produzione: `LDClient.get()!.stringVariation(forKey: key.rawValue, defaultValue: "")`
        let value = client.stringVariation(forKey: key.rawValue, defaultValue: "")
        return value.isEmpty ? nil : value
    }

    func doubleValue(for key: FeatureFlagKey) -> Double? {
        // In produzione: `LDClient.get()!.doubleVariation(forKey: key.rawValue, defaultValue: -1)`
        let value = client.doubleVariation(forKey: key.rawValue, defaultValue: -1)
        return value < 0 ? nil : value
    }

    /// Identifica il contesto utente in LaunchDarkly.
    ///
    /// QUANDO CHIAMARE:
    ///   - Al login: identifica l'utente autenticato con i suoi attributi reali
    ///   - Al logout: passa a un contesto anonimo per non mischiare i dati
    ///   - Al cambio di profilo (es. upgrade a premium): aggiorna gli attributi
    ///
    /// Dopo `identify`, LaunchDarkly riceve la lista di flag aggiornati per il nuovo utente.
    /// Il `FeatureFlagService` chiama questo metodo tramite `fetch()`.
    func fetch() async throws {
        // In produzione: `LDClient.get()!.identify(context: ldContext)` dove
        // `ldContext` è un `LDContext` costruito dal `userContext`
        try await client.identify(context: userContext)

        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[LaunchDarkly] ✅ Contesto utente aggiornato: \(userContext.key)")
        }
    }
}
