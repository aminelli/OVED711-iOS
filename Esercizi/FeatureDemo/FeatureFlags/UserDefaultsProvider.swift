//
//  UserDefaultsProvider.swift
//  FeatureDemo
//
//  Implementazione di FeatureFlagProvider basata su UserDefaults.
//
//  Casi d'uso principali:
//    1. Override locali durante lo sviluppo e il QA testing
//    2. Strato di fallback nel CompositeAdapter quando il remoto non è disponibile
//    3. Persistenza degli override impostati dalla dashboard di debug
//
//  NOTA SULLA THREAD SAFETY:
//  `UserDefaults` è thread-safe per le singole operazioni di lettura/scrittura.
//  La classe usa `@unchecked Sendable` per conformarsi a `Sendable` in Swift 6:
//  le operazioni su UserDefaults sono atomiche e non richiedono ulteriori lock.
//
//  NOTA SUL PREFISSO DELLE CHIAVI:
//  Viene aggiunto il prefisso "ff_" a tutte le chiavi per evitare collisioni
//  con altri valori già presenti in UserDefaults (es. preferenze utente, NSUserActivity, ecc.)

import Foundation

// MARK: - UserDefaultsProvider

/// Provider che legge (e scrive) i feature flag da/in UserDefaults.
///
/// Supporta la distinzione tra "chiave non impostata" e "chiave impostata a false"
/// usando `object(forKey:)` come sentinella, prima di leggere il valore effettivo.
final class UserDefaultsProvider: FeatureFlagProvider, @unchecked Sendable {

    // MARK: - Proprietà

    /// Suite UserDefaults da utilizzare.
    /// Iniettabile per i test: permette di usare una suite isolata senza effetti collaterali.
    private let defaults: UserDefaults

    /// Prefisso anteposto a tutte le chiavi per evitare collisioni nello spazio globale.
    private let keyPrefix: String

    // MARK: - Inizializzazione

    /// - Parameters:
    ///   - defaults: Suite di UserDefaults da usare (default: `.standard`)
    ///   - keyPrefix: Prefisso per le chiavi (default: `"ff_"`)
    init(defaults: UserDefaults = .standard, keyPrefix: String = "ff_") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    // MARK: - FeatureFlagProvider — Lettura

    func boolValue(for key: FeatureFlagKey) -> Bool {
        let storageKey = prefixed(key)
        // Usa `object(forKey:)` per distinguere "non impostato" (nil) da "impostato a false"
        // Se la chiave non è mai stata impostata, `bool(forKey:)` restituirebbe `false`
        // anche per flag il cui default è `true`, causando un bug silenzioso.
        if defaults.object(forKey: storageKey) != nil {
            return defaults.bool(forKey: storageKey)
        }
        // Fallback al valore di default dichiarato nel flag
        return key.defaultBoolValue
    }

    func stringValue(for key: FeatureFlagKey) -> String? {
        defaults.string(forKey: prefixed(key))
    }

    func doubleValue(for key: FeatureFlagKey) -> Double? {
        let storageKey = prefixed(key)
        guard defaults.object(forKey: storageKey) != nil else { return nil }
        return defaults.double(forKey: storageKey)
    }

    // MARK: - Scrittura (usata da CompositeAdapter e dalla dashboard di debug)

    /// Imposta un override booleano locale per il flag specificato.
    ///
    /// - Parameters:
    ///   - value: Valore booleano da impostare
    ///   - key: Chiave del flag da sovrascrivere
    func set(_ value: Bool, for key: FeatureFlagKey) {
        defaults.set(value, forKey: prefixed(key))
    }

    /// Imposta un override stringa locale per il flag specificato.
    func set(_ value: String, for key: FeatureFlagKey) {
        defaults.set(value, forKey: prefixed(key))
    }

    /// Imposta un override numerico locale per il flag specificato.
    func set(_ value: Double, for key: FeatureFlagKey) {
        defaults.set(value, forKey: prefixed(key))
    }

    // MARK: - Reset degli override

    /// Rimuove l'override locale per il flag specificato.
    /// Dopo questa chiamata, il flag torna al suo valore di default o al valore remoto.
    func reset(_ key: FeatureFlagKey) {
        defaults.removeObject(forKey: prefixed(key))
    }

    /// Rimuove tutti gli override locali impostati tramite questo provider.
    func resetAll() {
        FeatureFlagKey.allCases.forEach { reset($0) }
    }

    // MARK: - Ispezione (usata dalla dashboard di debug)

    /// Restituisce `true` se esiste un override locale per il flag specificato.
    func hasOverride(for key: FeatureFlagKey) -> Bool {
        defaults.object(forKey: prefixed(key)) != nil
    }

    /// Restituisce tutti i flag che hanno un override locale attivo.
    var overriddenKeys: Set<FeatureFlagKey> {
        Set(FeatureFlagKey.allCases.filter { hasOverride(for: $0) })
    }

    // MARK: - Helper privato

    /// Costruisce la chiave di UserDefaults con il prefisso anteposto.
    private func prefixed(_ key: FeatureFlagKey) -> String {
        keyPrefix + key.rawValue
    }
}
