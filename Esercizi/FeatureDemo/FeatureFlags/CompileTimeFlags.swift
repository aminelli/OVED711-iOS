//
//  CompileTimeFlags.swift
//  FeatureDemo
//
//  Flag compile-time con direttive del preprocessore Swift (#if / #elseif / #else).
//
//  DIFFERENZA TRA COMPILE-TIME E RUNTIME FLAGS:
//  - Compile-time: la decisione è presa dal compilatore. Il codice dei rami non attivi
//    NON viene incluso nel binario. Ottimale per separare debug da produzione.
//  - Runtime (FeatureFlagService): la decisione è presa a runtime. Il codice di tutti
//    i rami è compilato ma il ramo corretto viene scelto in esecuzione.
//
//  QUANDO USARE I FLAG COMPILE-TIME:
//  - Abilitare/disabilitare la dashboard di debug (non deve mai essere in produzione)
//  - Configurare endpoint diversi per ambienti diversi (dev/staging/prod)
//  - Includere/escludere dipendenze di test che non devono stare in produzione
//  - Ottimizzazioni specifiche per architettura (iOS vs macOS vs watchOS)
//
//  COME DEFINIRE CUSTOM FLAGS IN XCODE:
//  Build Settings → Other Swift Flags → -D NOME_FLAG
//  (es: -D STAGING per l'ambiente di staging)

import Foundation

// MARK: - CompileTimeFlags

/// Namespace per i flag compile-time dell'applicazione.
/// Tutti i membri sono `static` e non richiedono istanziazione.
enum CompileTimeFlags {

    // MARK: - Ambiente di build

    /// `true` quando la build è in modalità DEBUG.
    ///
    /// Il blocco `#if DEBUG` è automaticamente definito da Xcode
    /// per le build di sviluppo. NON è definito per le build di Release/Archive.
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// `true` quando la build è destinata all'ambiente di Staging.
    ///
    /// Richiede la definizione manuale di `-D STAGING` in:
    /// Xcode → Target → Build Settings → Other Swift Flags
    static var isStagingBuild: Bool {
        #if STAGING
        return true
        #else
        return false
        #endif
    }

    /// `true` quando la build è di produzione (né DEBUG né STAGING).
    static var isProductionBuild: Bool {
        #if DEBUG || STAGING
        return false
        #else
        return true
        #endif
    }

    // MARK: - Funzionalità di sviluppo

    /// `true` se la dashboard di debug dei feature flag deve essere mostrata.
    ///
    /// Attiva in DEBUG e STAGING, mai in produzione.
    /// Usata per mostrare/nascondere il tab della dashboard nella UI.
    static var showFeatureFlagDashboard: Bool {
        #if DEBUG || STAGING
        return true
        #else
        return false
        #endif
    }

    /// `true` se il logging verboso è abilitato per i feature flag.
    ///
    /// In produzione, il logging viene silenzato per non impattare le performance
    /// e non esporre informazioni di configurazione nei log di sistema.
    static var isVerboseLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Ambiente di esecuzione

    /// `true` quando l'app è in esecuzione sul Simulator.
    ///
    /// Utile per disabilitare funzionalità che richiedono hardware fisico
    /// (es. Face ID, NFC, sensori di movimento) o per usare dati di mock.
    static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// `true` quando i test automatici (XCTest) sono in esecuzione.
    ///
    /// Permette di disabilitare animazioni, chiamate di rete reali e timer
    /// durante i test per renderli più veloci e deterministici.
    static var isRunningTests: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        return false
        #endif
    }
}

// MARK: - Valori di default specifici per ambiente

// I flag compile-time possono essere usati per definire configurazioni
// completamente diverse in base all'ambiente di build.
// Il compilatore include nel binario SOLO il ramo attivo.

#if DEBUG
/// Override predefiniti per l'ambiente di sviluppo.
///
/// In sviluppo, alcune funzionalità vengono abilitate per default per permettere
/// agli sviluppatori di testarle senza configurare il sistema remoto.
/// ATTENZIONE: questa variabile non esiste nei build di Release.
let developmentDefaultOverrides: [FeatureFlagKey: Bool] = [
    .rt_newOnboarding:            true,  // Testa sempre il nuovo onboarding in dev
    .rt_redesignedHome:           true,  // Lavora sempre con il nuovo design in dev
    .et_checkoutButtonColor:      false, // Mantieni la variante di controllo in dev
    .et_recommendationAlgorithm:  false,
    .ot_maintenanceMode:          false, // Non mostrare il banner di manutenzione in dev
    .ot_analyticsEnabled:         false, // Disabilita l'invio di analytics reali in dev
    .pt_premiumContent:           true,  // Simula l'accesso premium in sviluppo
    .pt_advancedExport:           true
]
#else
// In produzione, nessun override di default: ogni flag usa il suo `defaultBoolValue`
// definito in `FeatureFlagKey` e/o il valore configurato nel sistema remoto.
let developmentDefaultOverrides: [FeatureFlagKey: Bool] = [:]
#endif

// MARK: - Esempio di uso di #if per codice condizionale in linea

// Questi esempi mostrano come usare i flag compile-time direttamente nel codice
// (non come variabili, ma come direttive del preprocessore inline).

/*

 // Endpoint differente per ogni ambiente:
 let apiBaseURL: URL = {
     #if DEBUG
     return URL(string: "https://api-dev.myapp.com")!
     #elseif STAGING
     return URL(string: "https://api-staging.myapp.com")!
     #else
     return URL(string: "https://api.myapp.com")!
     #endif
 }()

 // Dipendenza di test inclusa solo in DEBUG:
 #if DEBUG
 import FakeNetworkLayer
 #endif

 // Tipo diverso in base all'ambiente:
 #if DEBUG
 typealias AnalyticsService = MockAnalyticsService
 #else
 typealias AnalyticsService = FirebaseAnalyticsService
 #endif

*/
