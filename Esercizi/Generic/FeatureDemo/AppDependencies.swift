//
//  AppDependencies.swift
//  FeatureDemo
//
//  Contenitore delle dipendenze dell'applicazione (Dependency Injection Container).
//
//  PATTERN: Service Locator / Composition Root
//  Tutte le dipendenze vengono create una sola volta in questo punto centrale
//  e distribuite al resto dell'app tramite SwiftUI `@Environment`.
//
//  PERCHÉ @Observable:
//  `@Observable` (iOS 17+/iOS 26+) permette alle View SwiftUI di osservare
//  automaticamente le proprietà di questa classe e aggiornarsi quando cambiano.
//
//  PERCHÉ @MainActor:
//  Tutte le View SwiftUI vengono eseguite sul MainActor.
//  Rendere `AppDependencies` @MainActor garantisce che i ViewModel e le View
//  accedano alle dipendenze sempre nello stesso contesto di isolamento.
//
//  BOOTSTRAP ASINCRONO:
//  Il metodo `bootstrap()` viene chiamato da `FeatureDemoApp` nel `.task {}` della
//  finestra principale. Esegue il fetch remoto e configura le strategie di rollout
//  DOPO che la UI è già pronta e mostra valori di fallback (gestione cold start).

import SwiftUI
import Observation

// MARK: - AppDependencies

/// Contenitore centrale delle dipendenze dell'applicazione.
@Observable
@MainActor
final class AppDependencies {

    // MARK: - Layer Feature Flags (accesso diretto per la dashboard)

    /// Provider UserDefaults per gli override locali QA/sviluppo
    let userDefaultsProvider: UserDefaultsProvider

    /// Adapter Firebase Remote Config (simulato per questa demo)
    let firebaseAdapter: FirebaseRemoteConfigAdapter

    /// Adapter composito: combina override locali (alta priorità) + Firebase (bassa priorità)
    let compositeAdapter: CompositeAdapter

    /// Servizio centrale dei feature flag — actor per thread safety
    let featureFlagService: FeatureFlagService

    // MARK: - Layer A/B Testing e Analytics

    /// Connettore analytics per tracciare esperimenti e conversioni
    let analyticsConnector: FeatureFlagAnalyticsConnector

    /// Motore di valutazione delle strategie di rollout lato client
    let rolloutEngine: RolloutStrategyEngine

    // MARK: - ViewModels (pre-creati per evitare allocazioni ripetute nelle View)

    /// ViewModel della schermata principale
    let homeViewModel: HomeViewModel

    // MARK: - Contesto utente

    /// Contesto utente corrente (aggiornato dopo login/logout)
    private(set) var userContext: UserContext = .anonymous

    // MARK: - Stato del bootstrap

    /// `true` quando il bootstrap asincrono è completato
    private(set) var isBootstrapped: Bool = false

    // MARK: - Inizializzazione (sincrona — solo creazione degli oggetti)

    init() {
        // Step 1: Provider locale (UserDefaults)
        let udProvider = UserDefaultsProvider()
        self.userDefaultsProvider = udProvider

        // Step 2: Adapter remoto (Firebase)
        let fbAdapter = FirebaseRemoteConfigAdapter()
        self.firebaseAdapter = fbAdapter

        // Step 3: Composite adapter — override locale ha priorità su Firebase
        let composite = CompositeAdapter(
            remoteProvider: fbAdapter,
            localProvider: udProvider
        )
        self.compositeAdapter = composite

        // Step 4: FeatureFlagService — usa Composite come primario, UserDefaults come fallback
        let service = FeatureFlagService(
            primaryProvider: composite,
            fallbackProvider: udProvider
        )
        self.featureFlagService = service

        // Step 5: Analytics connector con tracker da console (in produzione: Firebase Analytics)
        let analytics = FeatureFlagAnalyticsConnector(
            tracker: ConsoleAnalyticsTracker(),
            userContext: .anonymous
        )
        self.analyticsConnector = analytics

        // Step 6: Motore di strategia lato client
        self.rolloutEngine = RolloutStrategyEngine(userContext: .anonymous)

        // Step 7: ViewModel — inietta le dipendenze necessarie
        self.homeViewModel = HomeViewModel(
            featureFlagService: service,
            analyticsConnector: analytics
        )
    }

    // MARK: - Bootstrap asincrono

    /// Avvia il processo di inizializzazione asincrona.
    ///
    /// Da chiamare nell'`.task {}` della WindowGroup in `FeatureDemoApp`.
    /// La UI è già visibile a questo punto con i valori di fallback (cold start gestito).
    func bootstrap() async {
        // Applica gli override compile-time per l'ambiente di sviluppo
        applyDevelopmentOverrides()

        // Configura le strategie di rollout lato client
        await configureRolloutStrategies()

        // Fetch della configurazione remota — gestisce il cold start internamente
        await featureFlagService.fetchRemoteConfiguration()

        // Carica i flag nel ViewModel della home
        await homeViewModel.onAppear()

        isBootstrapped = true

        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[AppDependencies] ✅ Bootstrap completato")
        }
    }

    // MARK: - Aggiornamento del contesto utente

    /// Aggiorna il contesto utente dopo il login.
    ///
    /// Da chiamare quando l'utente si autentica per abilitare il targeting personalizzato
    /// (permette a LaunchDarkly e alle strategie lato client di valutare i flag correttamente).
    func updateUserContext(_ context: UserContext) async {
        userContext = context
        await rolloutEngine.updateContext(context)

        // Invalida la cache dei flag per forzare la rivalutazione con il nuovo contesto
        await featureFlagService.invalidateAllCache()
    }

    // MARK: - Privati

    /// Applica gli override predefiniti per l'ambiente di sviluppo.
    /// Solo in DEBUG: in produzione `developmentDefaultOverrides` è un dizionario vuoto.
    private func applyDevelopmentOverrides() {
        guard CompileTimeFlags.isDebugBuild else { return }

        for (key, value) in developmentDefaultOverrides {
            // Non sovrascrivere se l'utente ha già impostato un override manuale
            if !compositeAdapter.hasLocalOverride(for: key) {
                compositeAdapter.setLocalOverride(value, for: key)
            }
        }

        if CompileTimeFlags.isVerboseLoggingEnabled {
            print("[AppDependencies] 🛠 Override sviluppo applicati: \(developmentDefaultOverrides.count) flag")
        }
    }

    /// Configura le strategie di rollout lato client per gli experiment toggle.
    ///
    /// Queste strategie si applicano SOLO quando il flag non ha un valore
    /// esplicito nel sistema remoto o locale. In pratica, fungono da logica
    /// di targeting aggiuntiva lato client.
    private func configureRolloutStrategies() async {
        // Esperimento colore pulsante: rollout al 50% degli utenti
        await rolloutEngine.register(
            strategy: PercentageRolloutStrategy(
                flagKey: .et_checkoutButtonColor,
                percentage: 50.0
            ),
            for: .et_checkoutButtonColor
        )

        // Nuovo onboarding: solo per beta tester e QA
        await rolloutEngine.register(
            strategy: AnyOfStrategy(strategies: [
                UserListStrategy(allowedUserIDs: ["qa-user-1", "qa-user-2", "beta-user-001"]),
                PercentageRolloutStrategy(flagKey: .rt_newOnboarding, percentage: 20.0)
            ]),
            for: .rt_newOnboarding
        )

        // Contenuto premium: solo per utenti con abbonamento
        await rolloutEngine.register(
            strategy: PremiumUsersStrategy(),
            for: .pt_premiumContent
        )
    }
}
