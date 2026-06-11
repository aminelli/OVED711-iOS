//
//  FeatureFlagProvider.swift
//  FeatureDemo
//
//  Astrazione basata su protocolli (Protocol-Based Abstraction) per i Feature Flag.
//
//  Questo protocollo definisce il contratto che ogni sorgente di flag deve rispettare,
//  che sia UserDefaults, Firebase Remote Config, LaunchDarkly o un mock per i test.
//
//  PRINCIPIO DI PROGETTAZIONE — Dependency Inversion Principle (DIP):
//  Il codice applicativo dipende SOLO da questa astrazione, mai dalle implementazioni
//  concrete. Questo permette di:
//    - Sostituire il provider remoto senza toccare il codice app
//    - Iniettare provider mock nei test unitari
//    - Comporre provider con il pattern Composite (vedi CompositeAdapter)
//
//  CONFORMANCE A `Sendable`:
//  Necessaria per Swift 6 strict concurrency: il provider può essere usato
//  da qualsiasi contesto di concorrenza (actor, Task, MainActor) in sicurezza.

import Foundation

// MARK: - FeatureFlagProvider

/// Protocollo che astrae la sorgente di lettura dei feature flag.
///
/// Ogni implementazione concreta (UserDefaults, Firebase, LaunchDarkly, Mock)
/// deve conformarsi a questo protocollo.
protocol FeatureFlagProvider: Sendable {

    /// Restituisce il valore booleano per il flag specificato.
    ///
    /// Se il flag non è definito nella sorgente, l'implementazione DEVE restituire
    /// `key.defaultBoolValue` per garantire un comportamento prevedibile.
    func boolValue(for key: FeatureFlagKey) -> Bool

    /// Restituisce il valore stringa per il flag, oppure `nil` se non definito.
    ///
    /// Usato per flag di tipo stringa: varianti di testo, URL, nomi di configurazione.
    func stringValue(for key: FeatureFlagKey) -> String?

    /// Restituisce il valore numerico (Double) per il flag, oppure `nil` se non definito.
    ///
    /// Usato per soglie numeriche, percentuali, durate temporali, ecc.
    func doubleValue(for key: FeatureFlagKey) -> Double?

    /// Aggiorna la configurazione recuperandola dal provider remoto.
    ///
    /// Per i provider locali (UserDefaults, in-memory) questa operazione è no-op.
    /// Deve lanciare un errore se il fetch remoto fallisce, per permettere
    /// al `FeatureFlagService` di gestire il fallback.
    func fetch() async throws
}

// MARK: - Implementazioni di default (extension)

extension FeatureFlagProvider {

    /// Per default, nessun valore stringa disponibile.
    func stringValue(for key: FeatureFlagKey) -> String? { nil }

    /// Per default, nessun valore numerico disponibile.
    func doubleValue(for key: FeatureFlagKey) -> Double? { nil }

    /// Per default, il fetch è un no-op (provider puramente locali).
    func fetch() async throws {}
}

// MARK: - FeatureFlagValue

/// Tipo enumerato che rappresenta il valore di un feature flag indipendentemente dal tipo.
///
/// Usato nella dashboard di debug per mostrare i valori senza conoscerne il tipo a priori.
enum FeatureFlagValue: CustomStringConvertible, Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case double(Double)

    var description: String {
        switch self {
        case .bool(let v):   return v ? "✓ true" : "✗ false"
        case .string(let v): return v
        case .double(let v): return String(format: "%.4f", v)
        }
    }

    /// Restituisce `true` solo se il valore booleano è `true`
    var boolValue: Bool {
        if case .bool(let v) = self { return v }
        return false
    }
}

// MARK: - FeatureFlagError

/// Errori che possono verificarsi durante il fetch della configurazione remota.
enum FeatureFlagError: LocalizedError, Sendable {

    /// Il provider non è ancora stato inizializzato (es. SDK non configurato)
    case providerNotInitialized(providerName: String)

    /// Errore di rete durante il fetch
    case networkError(underlying: Error)

    /// Il fetch ha avuto successo ma non ci sono dati da attivare
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .providerNotInitialized(let name):
            return "Provider '\(name)' non inizializzato. Verificare la configurazione SDK."
        case .networkError(let error):
            return "Errore di rete durante il fetch: \(error.localizedDescription)"
        case .noDataAvailable:
            return "Fetch completato ma nessun dato disponibile da attivare."
        }
    }
}
