//
//  CompositeAdapter.swift
//  FeatureDemo
//
//  Composite Adapter: override locale su configurazione remota.
//
//  PATTERN: Composite (GoF) applicato ai Feature Flag Provider
//
//  Il CompositeAdapter combina due provider con una logica di priorità esplicita:
//    1. Provider locale (UserDefaults) — ALTA PRIORITÀ per override QA/sviluppo
//    2. Provider remoto (Firebase/LaunchDarkly) — BASSA PRIORITÀ, configurazione prod
//
//  Un flag viene letto dal provider locale SOLO se è stato esplicitamente
//  "sovrascritto" tramite `setLocalOverride(_:for:)`.
//  In assenza di override locale, il valore remoto è quello restituito.
//
//  CASI D'USO:
//    - QA: il tester imposta override locali per testare scenari specifici
//      senza modificare la configurazione globale su Firebase/LaunchDarkly
//    - Sviluppo: lo sviluppatore abilita un flag in sviluppo mentre rimane
//      disabilitato per tutti gli altri utenti nel sistema remoto
//    - Cold start: mentre il remoto si carica, usa i valori di UserDefaults
//      (se presenti da una sessione precedente) come cache locale
//
//  THREAD SAFETY:
//  Usa `@unchecked Sendable` perché la mutazione di `overriddenKeys` non è
//  protetta da un lock. In un'app di produzione, considerare di renderlo un actor
//  o usare un `NSLock` per proteggere `overriddenKeys`.

import Foundation

// MARK: - CompositeAdapter

/// Adapter composito che applica override locali sulla configurazione remota.
/// Implementa il pattern "Local Override Remote" per QA e sviluppo.
final class CompositeAdapter: FeatureFlagProvider, @unchecked Sendable {

    // MARK: - Proprietà

    /// Provider remoto con la configurazione di produzione.
    private let remoteProvider: any FeatureFlagProvider

    /// Provider locale che contiene gli override (basato su UserDefaults).
    private let localProvider: UserDefaultsProvider

    /// Set delle chiavi che hanno un override locale attivo.
    ///
    /// Un flag viene letto dal `localProvider` SOLO se la sua chiave è in questo set.
    /// Questo evita che valori precedentemente impostati in UserDefaults per altri scopi
    /// vengano erroneamente interpretati come override dei feature flag.
    private var overriddenKeys: Set<FeatureFlagKey>

    // MARK: - Inizializzazione

    /// - Parameters:
    ///   - remoteProvider: Provider con i valori remoti di produzione
    ///   - localProvider: Provider locale per gli override (UserDefaults)
    ///   - initialOverrides: Override già attivi all'inizializzazione (es. ripristinati da sessione precedente)
    init(
        remoteProvider: any FeatureFlagProvider,
        localProvider: UserDefaultsProvider,
        initialOverrides: Set<FeatureFlagKey> = []
    ) {
        self.remoteProvider = remoteProvider
        self.localProvider = localProvider
        // Sincronizza gli override attivi con quello che UserDefaults già contiene
        self.overriddenKeys = initialOverrides.union(localProvider.overriddenKeys)
    }

    // MARK: - FeatureFlagProvider

    func boolValue(for key: FeatureFlagKey) -> Bool {
        // Override locale ha SEMPRE la priorità sul valore remoto
        if overriddenKeys.contains(key) {
            let localValue = localProvider.boolValue(for: key)
            if CompileTimeFlags.isVerboseLoggingEnabled {
                print("[CompositeAdapter] \(key.rawValue) → override locale: \(localValue)")
            }
            return localValue
        }
        // Nessun override: usa il valore remoto
        return remoteProvider.boolValue(for: key)
    }

    func stringValue(for key: FeatureFlagKey) -> String? {
        if overriddenKeys.contains(key) {
            return localProvider.stringValue(for: key)
        }
        return remoteProvider.stringValue(for: key)
    }

    func doubleValue(for key: FeatureFlagKey) -> Double? {
        if overriddenKeys.contains(key) {
            return localProvider.doubleValue(for: key)
        }
        return remoteProvider.doubleValue(for: key)
    }

    /// Il fetch viene delegato interamente al provider remoto.
    func fetch() async throws {
        try await remoteProvider.fetch()
    }

    // MARK: - Gestione degli override locali

    /// Imposta un override locale booleano per il flag specificato.
    ///
    /// Dopo questa chiamata, `boolValue(for: key)` restituirà `value`
    /// indipendentemente dal valore configurato nel sistema remoto.
    ///
    /// - Important: Chiamare `featureFlagService.invalidateCache(for: key)` dopo
    ///   questo metodo per propagare la modifica ai ViewModel in ascolto.
    func setLocalOverride(_ value: Bool, for key: FeatureFlagKey) {
        localProvider.set(value, for: key)
        overriddenKeys.insert(key)
        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[CompositeAdapter] Override impostato: \(key.rawValue) = \(value)")
        }
    }

    /// Rimuove l'override locale per il flag specificato.
    /// Dopo questa chiamata, il flag tornerà a usare il valore dal provider remoto.
    func removeLocalOverride(for key: FeatureFlagKey) {
        localProvider.reset(key)
        overriddenKeys.remove(key)
        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[CompositeAdapter] Override rimosso: \(key.rawValue)")
        }
    }

    /// Rimuove tutti gli override locali.
    func removeAllLocalOverrides() {
        localProvider.resetAll()
        overriddenKeys.removeAll()
        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[CompositeAdapter] Tutti gli override rimossi")
        }
    }

    /// Indica se un flag ha un override locale attivo.
    func hasLocalOverride(for key: FeatureFlagKey) -> Bool {
        overriddenKeys.contains(key)
    }

    /// Restituisce tutte le chiavi con un override locale attivo.
    var allOverriddenKeys: Set<FeatureFlagKey> {
        overriddenKeys
    }
}
