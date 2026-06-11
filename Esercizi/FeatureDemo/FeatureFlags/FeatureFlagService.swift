//
//  FeatureFlagService.swift
//  FeatureDemo
//
//  Servizio centrale per la gestione dei Feature Flag.
//
//  PATTERN ARCHITETTURALE — Actor per thread safety:
//  Implementato come `actor` di Swift 6. Tutti gli accessi allo stato interno
//  (cache, continuations, isPrimaryLoaded) sono serializzati automaticamente
//  dall'esecutore dell'actor, senza race condition e senza lock manuali.
//
//  GESTIONE DEL COLD START:
//  Al primo avvio, il provider remoto potrebbe non aver ancora caricato i dati.
//  Il servizio usa `isPrimaryLoaded` per decidere quale provider usare:
//    - false → usa il fallback (UserDefaults / valori di default) per risposta immediata
//    - true  → usa il provider primario (remoto) per valori aggiornati
//
//  AGGIORNAMENTI REAL-TIME:
//  Il servizio espone un `AsyncStream` di `FeatureFlagKey` che emette ogni chiave
//  il cui valore è cambiato. I ViewModel possono osservare questo stream per
//  aggiornare la UI senza polling.

import Foundation

// MARK: - FeatureFlagService

/// Servizio actor-isolated per la lettura thread-safe dei feature flag.
///
/// Gestisce la priorità tra provider primario (remoto) e provider di fallback (locale),
/// mantiene una cache in-memory e distribuisce aggiornamenti via AsyncStream.
actor FeatureFlagService {

    // MARK: - Proprietà

    /// Provider principale — solitamente remoto (Firebase Remote Config, LaunchDarkly).
    private let primaryProvider: any FeatureFlagProvider

    /// Provider di fallback — locale (UserDefaults o valori di default statici).
    /// Usato quando il provider primario non è ancora caricato o ha fallito.
    private let fallbackProvider: any FeatureFlagProvider

    /// Cache in-memory: evita chiamate ripetute ai provider per lo stesso flag
    /// durante lo stesso ciclo di vita del servizio.
    private var cache: [FeatureFlagKey: Bool] = [:]

    /// `true` quando il provider primario ha completato almeno un fetch con successo.
    /// Usato per gestire il cold start problem.
    private(set) var isPrimaryLoaded: Bool = false

    /// Dizionario di continuations per gli AsyncStream attivi.
    /// Ogni observer (ViewModel) riceve la propria continuation.
    /// Chiave: Int incrementale — sostituisce UUID per evitare `UUID()` che è
    /// @MainActor-isolated in iOS 26 e non può essere chiamato dentro un actor non-MainActor.
    private var updateContinuations: [Int: AsyncStream<FeatureFlagKey>.Continuation] = [:]

    /// Contatore monotono usato come chiave univoca per le continuations.
    private var nextContinuationID: Int = 0

    // MARK: - Inizializzazione

    /// - Parameters:
    ///   - primaryProvider: Provider con la priorità più alta (es. remoto)
    ///   - fallbackProvider: Provider usato come fallback (es. UserDefaults)
    init(
        primaryProvider: any FeatureFlagProvider,
        fallbackProvider: any FeatureFlagProvider
    ) {
        self.primaryProvider = primaryProvider
        self.fallbackProvider = fallbackProvider
    }

    // MARK: - Lettura dei flag

    /// Restituisce il valore booleano di un flag con logica di fallback.
    ///
    /// Ordine di priorità:
    ///   1. Cache in-memory (se disponibile e provider primario caricato)
    ///   2. Provider primario (se `isPrimaryLoaded == true`)
    ///   3. Provider di fallback (sempre disponibile)
    func isEnabled(_ key: FeatureFlagKey) -> Bool {
        // Controlla la cache solo se il provider primario è stato caricato
        if isPrimaryLoaded, let cached = cache[key] {
            return cached
        }

        // Cold start: usa il fallback per risposta immediata senza latenza
        guard isPrimaryLoaded else {
            return fallbackProvider.boolValue(for: key)
        }

        // Provider primario caricato: leggi il valore aggiornato e mettilo in cache
        let value = primaryProvider.boolValue(for: key)
        cache[key] = value
        return value
    }

    /// Restituisce il valore stringa di un flag con fallback.
    func stringValue(for key: FeatureFlagKey) -> String? {
        guard isPrimaryLoaded else {
            return fallbackProvider.stringValue(for: key)
        }
        // Il provider primario ha priorità; usa il fallback solo se nil
        return primaryProvider.stringValue(for: key)
            ?? fallbackProvider.stringValue(for: key)
    }

    /// Restituisce il valore numerico di un flag con fallback.
    func doubleValue(for key: FeatureFlagKey) -> Double? {
        guard isPrimaryLoaded else {
            return fallbackProvider.doubleValue(for: key)
        }
        return primaryProvider.doubleValue(for: key)
            ?? fallbackProvider.doubleValue(for: key)
    }

    // MARK: - Fetch dalla sorgente remota

    /// Recupera la configurazione aggiornata dal provider primario.
    ///
    /// GESTIONE DEL COLD START:
    /// Questa funzione è progettata per essere chiamata all'avvio dell'app.
    /// Se fallisce, l'app continua a funzionare con i valori di fallback.
    /// Non rilancia l'errore: il fallback è sempre disponibile.
    func fetchRemoteConfiguration() async {
        do {
            // Richiedi il fetch al provider primario (può richiedere tempo di rete)
            try await primaryProvider.fetch()

            // Invalida la cache per forzare la rilettura con i nuovi valori remoti
            cache.removeAll()

            // Segna il provider primario come caricato con successo
            isPrimaryLoaded = true

            // Notifica tutti gli observer che la configurazione è cambiata
            notifyAllFlagsUpdated()

        } catch {
            // Non rilancia: l'app rimane operativa con il fallback
            // In un progetto reale, loggare l'errore con il sistema di crash reporting
            print("[FeatureFlagService] ⚠️ Fetch remoto fallito: \(error.localizedDescription)")
            print("[FeatureFlagService] ℹ️ L'app continua a usare i valori di fallback.")
        }
    }

    // MARK: - Aggiornamenti real-time (AsyncStream / Swift 6 async-await)

    /// Restituisce un `AsyncStream` che emette le chiavi dei flag aggiornati.
    ///
    /// Ogni chiamata restituisce uno stream indipendente: ogni ViewModel può
    /// avere il suo stream senza interferire con gli altri.
    ///
    /// USO RACCOMANDATO in un ViewModel:
    /// ```swift
    /// func startObserving() {
    ///     observationTask = Task {
    ///         let stream = await featureFlagService.flagUpdates()
    ///         for await updatedKey in stream {
    ///             guard !Task.isCancelled else { break }
    ///             await self.handleFlagUpdate(updatedKey)
    ///         }
    ///     }
    /// }
    /// ```
    func flagUpdates() -> AsyncStream<FeatureFlagKey> {
        // `makeStream()` è l'API moderna (Swift 5.9+) che separa stream e continuation
        let (stream, continuation) = AsyncStream.makeStream(of: FeatureFlagKey.self)
        nextContinuationID += 1
        let id = nextContinuationID

        // Registra la continuation per poter inviare eventi in futuro
        updateContinuations[id] = continuation

        // Pulizia automatica quando il consumatore annulla lo stream (es. ViewModel deinit)
        continuation.onTermination = { [id] _ in
            // `onTermination` è @Sendable e può essere chiamato da qualsiasi contesto.
            // Usiamo un Task per tornare sull'esecutore dell'actor in sicurezza.
            Task { [weak self] in
                await self?.removeContinuation(id: id)
            }
        }

        return stream
    }

    // MARK: - Invalidazione cache (usata da CompositeAdapter e dashboard di debug)

    /// Invalida la cache per un singolo flag e notifica gli observer.
    ///
    /// Da chiamare dopo aver impostato un override locale via CompositeAdapter
    /// per far sì che il nuovo valore venga riletto al prossimo accesso.
    func invalidateCache(for key: FeatureFlagKey) {
        cache.removeValue(forKey: key)
        notifyObservers(for: key)
    }

    /// Invalida l'intera cache e notifica gli observer per tutti i flag.
    func invalidateAllCache() {
        cache.removeAll()
        notifyAllFlagsUpdated()
    }

    // MARK: - Lettura batch (utile per la dashboard di debug)

    /// Restituisce una snapshot del valore corrente di tutti i flag.
    /// Utile per popolare la dashboard di debug con tutti i valori in una sola chiamata.
    func allCurrentValues() -> [FeatureFlagKey: Bool] {
        Dictionary(uniqueKeysWithValues: FeatureFlagKey.allCases.map { key in
            (key, isEnabled(key))
        })
    }

    // MARK: - Privati

    private func removeContinuation(id: Int) {
        updateContinuations.removeValue(forKey: id)
    }

    /// Invia un aggiornamento per un singolo flag a tutti gli observer.
    private func notifyObservers(for key: FeatureFlagKey) {
        updateContinuations.values.forEach { $0.yield(key) }
    }

    /// Invia un aggiornamento per tutti i flag a tutti gli observer.
    /// Usato dopo un fetch remoto completo o un reset totale della cache.
    private func notifyAllFlagsUpdated() {
        for key in FeatureFlagKey.allCases {
            updateContinuations.values.forEach { $0.yield(key) }
        }
    }
}
