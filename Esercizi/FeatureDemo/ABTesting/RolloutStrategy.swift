//
//  RolloutStrategy.swift
//  FeatureDemo
//
//  Strategie di rollout per i Feature Flag.
//
//  Le strategie definiscono COME e PER CHI un flag viene attivato,
//  separando la logica di targeting dal codice del servizio.
//
//  PATTERN: Strategy (GoF)
//  Ogni strategia è un tipo che implementa il protocollo `RolloutStrategy`.
//  Possono essere composte (AND/OR) per creare regole di targeting complesse.
//
//  ESEMPI DI STRATEGIE COMPOSITE:
//  "Abilita per utenti premium in Italia con app >= 3.0":
//    AllOfStrategy(strategies: [
//        PremiumUsersStrategy(),
//        CountryStrategy(allowedCountries: ["IT"]),
//        AppVersionStrategy(minimumVersion: "3.0")
//    ])
//
//  "Abilita per il team QA o per utenti premium":
//    AnyOfStrategy(strategies: [
//        UserListStrategy(allowedUserIDs: ["qa-user-1", "qa-user-2"]),
//        PremiumUsersStrategy()
//    ])

import Foundation

// MARK: - UserContext

/// Contesto dell'utente corrente, usato dalle strategie di rollout per il targeting.
///
/// Deve essere aggiornato quando l'utente effettua login/logout
/// o quando cambiano attributi rilevanti (es. upgrade a premium).
struct UserContext: Sendable, Equatable {
    let userID: String
    let email: String?
    let isPremium: Bool
    let appVersion: String
    let country: String

    /// Contesto anonimo — usato prima dell'autenticazione.
    ///
    /// `nonisolated(unsafe)` garantisce che questa proprietà sia accessibile da qualsiasi
    /// contesto di concorrenza in Swift 6.3 / iOS 26, senza che il compilatore possa
    /// inferire isolamento @MainActor. È sicuro perché il valore è costante (only-init)
    /// e `UserContext` è `Sendable` (struct con soli value types).
    static let anonymous = UserContext(
        userID: "anonymous",
        email: nil,
        isPremium: false,
        appVersion: "unknown",
        country: "unknown"
    )
}

// MARK: - RolloutStrategy Protocol

/// Protocollo che definisce una strategia di rollout per un feature flag.
///
/// Conforme a `Sendable` per essere usato in contesti concorrenti (actors, Task).
protocol RolloutStrategy: Sendable {
    /// Determina se il flag deve essere attivo per il contesto utente fornito.
    func isActive(for context: UserContext) -> Bool
}

// MARK: - Strategie concrete

/// Strategia: flag sempre attivo per tutti gli utenti (100% rollout).
struct AllUsersStrategy: RolloutStrategy {
    func isActive(for context: UserContext) -> Bool { true }
}

/// Strategia: flag sempre inattivo (0% rollout — utile per kill switch).
struct NoUsersStrategy: RolloutStrategy {
    func isActive(for context: UserContext) -> Bool { false }
}

/// Strategia: rollout percentuale deterministico.
///
/// Usa `UserBucketing` per garantire che lo stesso utente veda sempre
/// la stessa variante. La percentuale è configurabile da 0 a 100.
struct PercentageRolloutStrategy: RolloutStrategy {
    let flagKey: FeatureFlagKey
    /// Percentuale di utenti che vedono il flag attivo [0.0, 100.0]
    let percentage: Double

    func isActive(for context: UserContext) -> Bool {
        UserBucketing.isInTreatmentGroup(
            userID: context.userID,
            flagKey: flagKey,
            rolloutPercentage: percentage
        )
    }
}

/// Strategia: attivo solo per utenti in una lista esplicita.
///
/// Tipicamente usata per: beta tester interni, team QA, utenti di test specifici.
struct UserListStrategy: RolloutStrategy {
    /// Set di userID per cui il flag è attivo
    let allowedUserIDs: Set<String>

    func isActive(for context: UserContext) -> Bool {
        allowedUserIDs.contains(context.userID)
    }
}

/// Strategia: attivo solo per utenti con abbonamento premium.
struct PremiumUsersStrategy: RolloutStrategy {
    func isActive(for context: UserContext) -> Bool {
        context.isPremium
    }
}

/// Strategia: attivo solo per utenti in specifici paesi.
struct CountryStrategy: RolloutStrategy {
    let allowedCountries: Set<String>

    func isActive(for context: UserContext) -> Bool {
        allowedCountries.contains(context.country.uppercased())
    }
}

/// Strategia composita: AND — TUTTE le sotto-strategie devono essere soddisfatte.
///
/// Esempio: utente premium E in Italia E con app >= 3.0
struct AllOfStrategy: RolloutStrategy {
    let strategies: [any RolloutStrategy]

    func isActive(for context: UserContext) -> Bool {
        strategies.allSatisfy { $0.isActive(for: context) }
    }
}

/// Strategia composita: OR — almeno UNA delle sotto-strategie deve essere soddisfatta.
///
/// Esempio: team QA O utenti premium
struct AnyOfStrategy: RolloutStrategy {
    let strategies: [any RolloutStrategy]

    func isActive(for context: UserContext) -> Bool {
        strategies.contains { $0.isActive(for: context) }
    }
}

/// Strategia negazione: inverte il risultato di un'altra strategia.
///
/// Esempio: NotStrategy(PremiumUsersStrategy()) → attivo solo per utenti NON premium
struct NotStrategy: RolloutStrategy {
    let strategy: any RolloutStrategy

    func isActive(for context: UserContext) -> Bool {
        !strategy.isActive(for: context)
    }
}

// MARK: - RolloutStrategyEngine

/// Motore che registra e valuta le strategie di rollout per i flag.
///
/// Implementato come `actor` per la thread safety in Swift 6.
/// Il `FeatureFlagService` può utilizzare questo engine per valutare
/// flag con strategie di targeting complesse lato client.
actor RolloutStrategyEngine {

    // MARK: - Proprietà

    /// Mappa flag → strategia registrata
    private var strategies: [FeatureFlagKey: any RolloutStrategy] = [:]

    /// Contesto utente corrente
    private(set) var userContext: UserContext

    // MARK: - Inizializzazione

    /// - Parameter userContext: Contesto dell'utente. Passare `UserContext.anonymous`
    ///   prima del login. Non usa un default parameter perché in Swift 6.3 i valori
    ///   di default negli `actor` init sono valutati in contesto nonisolated, il che
    ///   potrebbe causare errori di isolamento anche con proprietà marcate nonisolated.
    init(userContext: UserContext) {
        self.userContext = userContext
    }

    // MARK: - Gestione del contesto utente

    /// Aggiorna il contesto utente (es. dopo il login o l'upgrade a premium).
    func updateContext(_ context: UserContext) {
        userContext = context
    }

    // MARK: - Registrazione delle strategie

    /// Registra una strategia di rollout per un flag specifico.
    ///
    /// Se il flag ha già una strategia registrata, viene sostituita.
    func register(strategy: any RolloutStrategy, for key: FeatureFlagKey) {
        strategies[key] = strategy
    }

    /// Rimuove la strategia registrata per un flag.
    func unregister(for key: FeatureFlagKey) {
        strategies.removeValue(forKey: key)
    }

    // MARK: - Valutazione

    /// Valuta se un flag è attivo per il contesto utente corrente.
    ///
    /// Se non è registrata una strategia per il flag, usa il `defaultBoolValue`
    /// definito nell'enum `FeatureFlagKey`.
    func isActive(for key: FeatureFlagKey) -> Bool {
        guard let strategy = strategies[key] else {
            return key.defaultBoolValue
        }
        return strategy.isActive(for: userContext)
    }

    /// Restituisce i valori calcolati di tutti i flag registrati
    /// per il contesto utente corrente.
    func evaluateAll() -> [FeatureFlagKey: Bool] {
        Dictionary(uniqueKeysWithValues: FeatureFlagKey.allCases.map { key in
            (key, isActive(for: key))
        })
    }
}
