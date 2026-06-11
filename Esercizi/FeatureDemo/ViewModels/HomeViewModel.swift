//
//  HomeViewModel.swift
//  FeatureDemo
//
//  ViewModel per la schermata principale con Dependency Injection dei Feature Flag.
//
//  PATTERN: MVVM con @Observable (Swift 5.9+/iOS 17+/iOS 26)
//
//  PRINCIPIO DI DI (Dependency Injection) PER I FEATURE FLAG:
//  Il ViewModel NON accede mai direttamente a UserDefaults, Firebase o LaunchDarkly.
//  Riceve il `FeatureFlagService` tramite il costruttore (constructor injection).
//  Questo garantisce:
//    - Testabilità: nei test si inietta un provider mock senza effetti collaterali
//    - Separazione delle responsabilità: il ViewModel legge i flag, non sa da dove vengono
//    - Indipendenza dalla piattaforma: si può sostituire il provider senza toccare il ViewModel
//
//  OSSERVAZIONE REAL-TIME:
//  Il ViewModel avvia un Task che consuma l'AsyncStream di `FeatureFlagService`.
//  Quando un flag cambia (es. dopo un fetch remoto), la UI viene aggiornata
//  automaticamente senza polling.
//
//  @MainActor:
//  Tutte le proprietà @Observable devono essere modificate sul MainActor per
//  aggiornare correttamente la UI di SwiftUI.

import SwiftUI
import Observation

// MARK: - HomeViewModel

/// ViewModel per la schermata principale, osservabile da SwiftUI.
@Observable
@MainActor
final class HomeViewModel {

    // MARK: - Stato dei feature flag (letto da FeatureFlagService)

    /// Release Toggle: mostra il nuovo flusso di onboarding
    private(set) var showNewOnboarding: Bool = false

    /// Release Toggle: usa il layout redesignato della home
    private(set) var useRedesignedHome: Bool = false

    /// Experiment Toggle: colore del pulsante (false = blu, true = verde)
    private(set) var useGreenButton: Bool = false

    /// Experiment Toggle: algoritmo di raccomandazione (false = collaborativo, true = content-based)
    private(set) var useContentBasedRecs: Bool = false

    /// Ops Toggle: mostra il banner di manutenzione
    private(set) var showMaintenanceBanner: Bool = false

    /// Permission Toggle: abilita le funzionalità premium
    private(set) var isPremiumEnabled: Bool = false

    // MARK: - Stato UI

    /// `true` durante il fetch remoto iniziale — mostra uno skeleton/placeholder
    private(set) var isLoadingRemoteConfig: Bool = true

    /// `true` quando il provider remoto ha caricato i dati con successo
    private(set) var isFlagsLoaded: Bool = false

    /// Variante dell'esperimento colore pulsante, calcolata per le analytics
    private(set) var buttonColorVariant: String = "control_blue"

    // MARK: - Dipendenze (iniettate tramite costruttore)

    private let featureFlagService: FeatureFlagService
    private let analyticsConnector: FeatureFlagAnalyticsConnector

    // MARK: - Task di osservazione degli aggiornamenti real-time

    /// Task di osservazione degli aggiornamenti real-time.
    /// Dichiarato `nonisolated(unsafe)` per permetterne la cancellazione nel `deinit`
    /// (nonisolated per definizione in Swift 6) senza violare l'isolamento del MainActor.
    /// La scrittura avviene sempre sul MainActor; la sola lettura nel `deinit` è sicura
    /// perché a quel punto non esistono altri riferimenti all'oggetto.
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    // MARK: - Inizializzazione

    /// - Parameters:
    ///   - featureFlagService: Servizio dei feature flag (iniettato dall'esterno)
    ///   - analyticsConnector: Connettore analytics per tracciare gli esperimenti
    init(
        featureFlagService: FeatureFlagService,
        analyticsConnector: FeatureFlagAnalyticsConnector
    ) {
        self.featureFlagService = featureFlagService
        self.analyticsConnector = analyticsConnector
    }

    deinit {
        // `observationTask` è nonisolated(unsafe): la cancellazione nel deinit è sicura
        // perché a questo punto non esistono altri riferimenti all'oggetto.
        observationTask?.cancel()
    }

    // MARK: - Ciclo di vita

    /// Inizializza il ViewModel: carica i flag e avvia l'osservazione real-time.
    ///
    /// Da chiamare in `.task {}` nella View associata, oppure dal `bootstrap()`
    /// dell'`AppDependencies`.
    func onAppear() async {
        // Mostra stato di caricamento durante il fetch remoto (cold start)
        isLoadingRemoteConfig = true

        // Leggi i flag dai provider disponibili (può usare fallback se remoto non ancora caricato)
        await loadAllFlags()

        // Avvia l'ascolto degli aggiornamenti in real-time
        startObservingFlagUpdates()

        isLoadingRemoteConfig = false
        isFlagsLoaded = await featureFlagService.isPrimaryLoaded

        // Traccia l'esposizione agli esperimenti attivi
        await trackActiveExperiments()
    }

    // MARK: - Caricamento dei flag

    /// Legge il valore corrente di tutti i flag osservati dal ViewModel.
    private func loadAllFlags() async {
        showNewOnboarding    = await featureFlagService.isEnabled(.rt_newOnboarding)
        useRedesignedHome    = await featureFlagService.isEnabled(.rt_redesignedHome)
        useGreenButton       = await featureFlagService.isEnabled(.et_checkoutButtonColor)
        useContentBasedRecs  = await featureFlagService.isEnabled(.et_recommendationAlgorithm)
        showMaintenanceBanner = await featureFlagService.isEnabled(.ot_maintenanceMode)
        isPremiumEnabled     = await featureFlagService.isEnabled(.pt_premiumContent)

        // Calcola la stringa della variante per le analytics
        buttonColorVariant = useGreenButton ? "treatment_green" : "control_blue"
    }

    // MARK: - Osservazione real-time degli aggiornamenti (AsyncStream)

    /// Avvia il Task che ascolta lo stream degli aggiornamenti dei flag.
    ///
    /// Ogni volta che un flag cambia (es. dopo un fetch remoto o un override dalla dashboard),
    /// il ViewModel aggiorna solo la proprietà corrispondente — non ricarica tutto.
    private func startObservingFlagUpdates() {
        // Cancella il task precedente se esiste (es. doppia chiamata a onAppear)
        observationTask?.cancel()

        // Il Task eredita il contesto @MainActor dalla chiamata (HomeViewModel è @MainActor)
        observationTask = Task { [weak self] in
            guard let self else { return }

            // Ottieni lo stream degli aggiornamenti dall'actor FeatureFlagService
            let stream = await featureFlagService.flagUpdates()

            // Consuma lo stream in modo asincrono — attende ogni evento senza bloccare il thread
            for await updatedKey in stream {
                // Interrompi se il Task è stato cancellato (es. ViewModel deallocato)
                guard !Task.isCancelled else { break }

                // Aggiorna solo il flag che è effettivamente cambiato (efficienza)
                await self.handleFlagUpdate(updatedKey)
            }
        }
    }

    /// Gestisce l'aggiornamento di un singolo flag ricevuto dallo stream.
    private func handleFlagUpdate(_ key: FeatureFlagKey) async {
        switch key {
        case .rt_newOnboarding:
            showNewOnboarding = await featureFlagService.isEnabled(.rt_newOnboarding)

        case .rt_redesignedHome:
            useRedesignedHome = await featureFlagService.isEnabled(.rt_redesignedHome)

        case .et_checkoutButtonColor:
            useGreenButton = await featureFlagService.isEnabled(.et_checkoutButtonColor)
            buttonColorVariant = useGreenButton ? "treatment_green" : "control_blue"
            // Ritraccia l'esposizione perché il flag è appena cambiato valore
            await analyticsConnector.trackExperimentExposure(
                flagKey: .et_checkoutButtonColor,
                variant: buttonColorVariant
            )

        case .et_recommendationAlgorithm:
            useContentBasedRecs = await featureFlagService.isEnabled(.et_recommendationAlgorithm)

        case .ot_maintenanceMode:
            showMaintenanceBanner = await featureFlagService.isEnabled(.ot_maintenanceMode)

        case .pt_premiumContent:
            isPremiumEnabled = await featureFlagService.isEnabled(.pt_premiumContent)

        default:
            break // Flag non osservato da questo ViewModel
        }

        // Aggiorna lo stato "caricato" dopo ogni aggiornamento
        isFlagsLoaded = await featureFlagService.isPrimaryLoaded
    }

    // MARK: - Analytics

    /// Traccia l'esposizione a tutti gli esperimenti attivi al momento del caricamento.
    private func trackActiveExperiments() async {
        // Experiment: colore pulsante checkout
        await analyticsConnector.trackExperimentExposure(
            flagKey: .et_checkoutButtonColor,
            variant: buttonColorVariant
        )

        // Experiment: algoritmo di raccomandazione
        let recVariant = useContentBasedRecs ? "treatment_content_based" : "control_collaborative"
        await analyticsConnector.trackExperimentExposure(
            flagKey: .et_recommendationAlgorithm,
            variant: recVariant
        )
    }

    /// Traccia la conversione (tap sul pulsante) collegata all'esperimento attivo.
    func trackCheckoutButtonTapped() async {
        await analyticsConnector.trackExperimentConversion(
            actionName: "checkout_button_tapped",
            flagKey: .et_checkoutButtonColor,
            variant: buttonColorVariant
        )
    }

    // MARK: - Dati calcolati per la UI

    /// Colore del pulsante di checkout basato sull'experiment toggle.
    var checkoutButtonColor: Color {
        useGreenButton ? .green : .blue
    }

    /// Etichetta dell'algoritmo di raccomandazione basata sull'experiment toggle.
    var recommendationAlgorithmLabel: String {
        useContentBasedRecs ? "Content-Based" : "Filtraggio Collaborativo"
    }
}
