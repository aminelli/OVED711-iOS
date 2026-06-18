//
//  AnalyticsConnector.swift
//  FeatureDemo
//
//  Connessione tra Feature Flag e sistema di Analytics.
//
//  PERCHÉ COLLEGARE FLAG E ANALYTICS:
//  Senza analytics, un esperimento A/B è cieco: non si sa se la variante B
//  ha migliorato le conversioni, il tempo di sessione, o il tasso di abbandono.
//  Collegare i flag alle analytics permette di:
//    - Misurare l'impatto statistico di ogni variante
//    - Segmentare le metriche per gruppo (control vs treatment)
//    - Decidere con dati quale variante "vince"
//    - Rilevare effetti collaterali inattesi di una funzionalità
//
//  EVENTO CHIAVE: `experiment_exposure`
//  Deve essere tracciato una sola volta per sessione per ogni esperimento,
//  nel momento in cui l'utente vede per la prima volta la variante assegnata.
//  Tracciarlo più volte gonfia artificialmente i numeri dell'esperimento.
//
//  STRUTTURA DEGLI EVENTI:
//  Segue le raccomandazioni di Amplitude, Mixpanel e Google Analytics 4:
//    - Nome evento in snake_case
//    - Proprietà: experiment_key, variant, user_id, attributi utente
//    - Timestamp aggiunto automaticamente

import Foundation

// MARK: - FeatureFlagAnalyticsEvent

/// Rappresenta un evento analytics generato dal sistema di feature flag.
struct FeatureFlagAnalyticsEvent: Sendable {
    /// Nome dell'evento in snake_case (segue le convenzioni di Amplitude/GA4)
    let name: String

    /// Proprietà dell'evento come dizionario stringa→stringa per massima compatibilità
    let properties: [String: String]

    /// Timestamp della creazione dell'evento.
    /// Passato esplicitamente dal chiamante per evitare dipendenze da contesti @MainActor
    /// (in iOS 26 / Swift 6.3, `Date()` è @MainActor-isolated nel body di un init).
    let timestamp: Date

    /// - Parameters:
    ///   - name: Nome dell'evento in snake_case
    ///   - properties: Proprietà dell'evento
    ///   - timestamp: Timestamp dell'evento (default calcolato dal chiamante con `Date()`)
    init(name: String, properties: [String: String], timestamp: Date) {
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
    }
}

// MARK: - AnalyticsTracker Protocol

/// Protocollo per il sistema di analytics.
///
/// Implementazioni concrete: Amplitude, Firebase Analytics, Mixpanel, Segment, ecc.
/// Conforme a `Sendable` per compatibilità con actor e contesti async.
protocol AnalyticsTracker: Sendable {
    func track(event: FeatureFlagAnalyticsEvent) async
}

// MARK: - ConsoleAnalyticsTracker

/// Tracker di analytics che stampa gli eventi in console.
/// Usato in sviluppo e nei test per verificare che gli eventi siano tracciati
/// correttamente senza inviare dati reali a servizi esterni.
struct ConsoleAnalyticsTracker: AnalyticsTracker {
    func track(event: FeatureFlagAnalyticsEvent) async {
        let propsDesc = event.properties
            .sorted { $0.key < $1.key }
            .map { "  \($0.key): \($0.value)" }
            .joined(separator: "\n")
        print("[Analytics] 📊 \(event.name)\n\(propsDesc)")
    }
}

// MARK: - NullAnalyticsTracker

/// Tracker no-op che non registra nulla.
/// Usato nei test unitari che non vogliono verificare gli eventi analytics.
struct NullAnalyticsTracker: AnalyticsTracker {
    func track(event: FeatureFlagAnalyticsEvent) async {}
}

// MARK: - FeatureFlagAnalyticsConnector

/// Connette il sistema di feature flag al tracker di analytics.
///
/// Responsabilità:
///   - Formattare gli eventi nel formato corretto per il tracker
///   - De-duplicare le esposizioni agli esperimenti nella stessa sessione
///   - Aggiungere il contesto utente a ogni evento
///
/// Implementato come `actor` per garantire che la de-duplicazione
/// (tramite `trackedExperiments`) sia thread-safe in Swift 6.
actor FeatureFlagAnalyticsConnector {

    // MARK: - Proprietà

    private let tracker: any AnalyticsTracker
    private let userContext: UserContext

    /// Tiene traccia degli esperimenti già esposti in questa sessione.
    /// La chiave è "\(flagKey.rawValue):\(variant)" per de-duplicare per variante.
    ///
    /// Motivazione: se il ViewModel viene aggiornato più volte perché il flag
    /// viene riletto, l'evento di esposizione non deve essere mandato più volte.
    private var trackedExposures: Set<String> = []

    // MARK: - Inizializzazione

    init(tracker: any AnalyticsTracker, userContext: UserContext) {
        self.tracker = tracker
        self.userContext = userContext
    }

    // MARK: - Tracciamento degli esperimenti

    /// Traccia l'esposizione di un utente a una variante di un esperimento.
    ///
    /// DE-DUPLICAZIONE: un'esposizione per la stessa coppia (flagKey, variant)
    /// viene tracciata una sola volta per sessione.
    ///
    /// - Parameters:
    ///   - flagKey: Chiave del flag dell'esperimento
    ///   - variant: Stringa che identifica la variante assegnata (es. "control", "treatment_a")
    func trackExperimentExposure(flagKey: FeatureFlagKey, variant: String) async {
        // Chiave univoca per la de-duplicazione
        let dedupeKey = "\(flagKey.rawValue):\(variant)"

        // Non tracciare se già esposto in questa sessione
        guard !trackedExposures.contains(dedupeKey) else { return }
        trackedExposures.insert(dedupeKey)

        let now = Date(timeIntervalSinceNow: 0)
        let event = await FeatureFlagAnalyticsEvent(
            name: "experiment_exposure",
            properties: [
                "experiment_key":  flagKey.rawValue,
                "variant":         variant,
                "user_id":         userContext.userID,
                "is_premium":      String(userContext.isPremium),
                "app_version":     userContext.appVersion,
                "country":         userContext.country,
                "flag_category":   flagKey.category.rawValue
            ],
            timestamp: now
        )

        await tracker.track(event: event)
    }

    /// Traccia la valutazione di un feature flag non-experiment (Release, Ops, Permission).
    ///
    /// Utile per monitorare quanti utenti vedono una funzionalità in fase di rollout
    /// o per verificare che un kill switch funzioni correttamente.
    ///
    /// - Parameters:
    ///   - flagKey: Chiave del flag valutato
    ///   - value: Valore risultante della valutazione
    func trackFlagEvaluation(flagKey: FeatureFlagKey, value: Bool) async {
        let now = Date(timeIntervalSinceNow: 0)
        let event = await FeatureFlagAnalyticsEvent(
            name: "feature_flag_evaluated",
            properties: [
                "flag_key":      flagKey.rawValue,
                "flag_category": flagKey.category.rawValue,
                "value":         String(value),
                "user_id":       userContext.userID
            ],
            timestamp: now
        )
        await tracker.track(event: event)
    }

    /// Traccia un'azione dell'utente collegata a un esperimento.
    ///
    /// Usato per collegare le conversioni (es. tap su "Acquista") all'esperimento.
    /// Il sistema di analytics può poi fare la jointura tra `experiment_exposure`
    /// e questo evento per calcolare il tasso di conversione per variante.
    ///
    /// - Parameters:
    ///   - actionName: Nome dell'azione (es. "purchase_button_tapped")
    ///   - flagKey: Chiave del flag dell'esperimento correlato
    ///   - variant: Variante attiva al momento dell'azione
    func trackExperimentConversion(
        actionName: String,
        flagKey: FeatureFlagKey,
        variant: String
    ) async {
        let now = Date(timeIntervalSinceNow: 0)
        let event = await FeatureFlagAnalyticsEvent(
            name: actionName,
            properties: [
                "experiment_key": flagKey.rawValue,
                "variant":        variant,
                "user_id":        userContext.userID,
                "is_conversion":  "true"
            ],
            timestamp: now
        )
        await tracker.track(event: event)
    }

    // MARK: - Gestione della sessione

    /// Resetta il tracking delle esposizioni.
    /// Da chiamare all'inizio di una nuova sessione (es. dopo il login).
    func resetSessionTracking() {
        trackedExposures.removeAll()
    }

    /// Restituisce il numero di esperimenti tracciati in questa sessione.
    var trackedExposureCount: Int { trackedExposures.count }
}
