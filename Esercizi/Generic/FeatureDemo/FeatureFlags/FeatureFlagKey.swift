//
//  FeatureFlagKey.swift
//  FeatureDemo
//
//  Convenzione di naming per i Feature Flag:
//  Prefisso che indica il tipo di toggle:
//    rt_ = Release Toggle    → attivazione graduale di nuove funzionalità
//    et_ = Experiment Toggle → A/B test e sperimentazione controllata
//    ot_ = Ops Toggle        → operazioni e manutenzione (kill switch)
//    pt_ = Permission Toggle → funzionalità riservate a ruoli/abbonamenti specifici
//
//  Struttura: <tipo>_<dominio>_<descrizione_breve>
//  Esempi:
//    rt_onboarding_new_flow   → Release toggle per il nuovo flusso di onboarding
//    et_checkout_button_color → Experiment toggle per il colore del pulsante di checkout
//    ot_maintenance_mode      → Ops toggle per la modalità manutenzione
//    pt_premium_content       → Permission toggle per il contenuto premium

import Foundation

// MARK: - FeatureFlagKey

/// Enumerazione centralizzata di tutte le chiavi dei feature flag dell'app.
///
/// Vantaggi di usare un'enum:
///   - Tipo-sicurezza: nessun errore di battitura nelle chiavi stringa
///   - Autocompletamento: l'IDE suggerisce tutti i flag disponibili
///   - Documentazione inline: ogni flag può essere documentato con commenti
///   - `CaseIterable`: permette di iterare su tutti i flag (es. dashboard di debug)
///   - `Sendable`: garantisce la sicurezza in contesti concorrenti (Swift 6)
enum FeatureFlagKey: String, CaseIterable, Sendable {

    // MARK: - Release Toggles (rt_)
    // Controllano il rilascio graduale di nuove funzionalità agli utenti.
    // Ciclo di vita: nascono disabilitati → rollout progressivo → rimozione quando al 100%.

    /// Nuovo flusso di onboarding — in fase di rollout progressivo (target: 20% → 100%)
    case rt_newOnboarding = "rt_new_onboarding"

    /// Home redesignata — visibile inizialmente solo ai beta tester interni
    case rt_redesignedHome = "rt_redesigned_home"

    // MARK: - Experiment Toggles (et_)
    // Usati per A/B testing e sperimentazione controllata.
    // Collegati al sistema di analytics per misurare l'impatto statistico.
    // Ciclo di vita: apertura esperimento → raccolta dati → decisione → chiusura.

    /// Colore del pulsante di checkout
    /// Variante A (false) = blu (#007AFF) | Variante B (true) = verde (#34C759)
    case et_checkoutButtonColor = "et_checkout_button_color"

    /// Algoritmo di raccomandazione contenuti
    /// Variante A (false) = filtraggio collaborativo | Variante B (true) = content-based
    case et_recommendationAlgorithm = "et_recommendation_algorithm"

    // MARK: - Ops Toggles (ot_)
    // Permettono al team operativo di gestire incidenti o manutenzione
    // senza dover rilasciare una nuova versione dell'app (kill switch).

    /// Modalità manutenzione — mostra un banner e disabilita le operazioni critiche
    case ot_maintenanceMode = "ot_maintenance_mode"

    /// Raccolta delle analytics — può essere disabilitata per privacy o durante incidenti
    case ot_analyticsEnabled = "ot_analytics_enabled"

    // MARK: - Permission Toggles (pt_)
    // Abilitano funzionalità riservate a utenti con permessi specifici.
    // La logica di chi ha il permesso vive nel backend, non nel flag stesso.

    /// Accesso al contenuto premium — solo per abbonati attivi
    case pt_premiumContent = "pt_premium_content"

    /// Esportazione avanzata in PDF/CSV — solo per account di livello Enterprise
    case pt_advancedExport = "pt_advanced_export"

    // MARK: - Valori di default

    /// Valore booleano di default per ogni flag.
    ///
    /// Usato come fallback in tre scenari:
    ///   1. Il provider remoto non è ancora stato caricato (cold start)
    ///   2. Il fetch remoto è fallito (errore di rete)
    ///   3. Il flag non è definito nel provider remoto (nuovi flag non ancora configurati)
    ///
    /// Principio di sicurezza: i default sono sempre conservativi (feature disabilitata).
    var defaultBoolValue: Bool {
        switch self {
        case .rt_newOnboarding:            return false
        case .rt_redesignedHome:           return false
        case .et_checkoutButtonColor:      return false // variante A (controllo)
        case .et_recommendationAlgorithm:  return false // filtraggio collaborativo
        case .ot_maintenanceMode:          return false // non in manutenzione per default
        case .ot_analyticsEnabled:         return true  // analytics attive per default
        case .pt_premiumContent:           return false // nessun accesso premium per default
        case .pt_advancedExport:           return false
        }
    }

    /// Categoria leggibile del toggle, usata nella dashboard di debug.
    var category: ToggleCategory {
        switch self {
        case .rt_newOnboarding, .rt_redesignedHome:
            return .release
        case .et_checkoutButtonColor, .et_recommendationAlgorithm:
            return .experiment
        case .ot_maintenanceMode, .ot_analyticsEnabled:
            return .ops
        case .pt_premiumContent, .pt_advancedExport:
            return .permission
        }
    }

    /// Descrizione leggibile del flag, usata nella dashboard di debug.
    var displayName: String {
        switch self {
        case .rt_newOnboarding:            return "Nuovo Onboarding"
        case .rt_redesignedHome:           return "Home Redesignata"
        case .et_checkoutButtonColor:      return "Colore Pulsante Checkout"
        case .et_recommendationAlgorithm:  return "Algoritmo Raccomandazioni"
        case .ot_maintenanceMode:          return "Modalità Manutenzione"
        case .ot_analyticsEnabled:         return "Analytics Abilitata"
        case .pt_premiumContent:           return "Contenuto Premium"
        case .pt_advancedExport:           return "Esportazione Avanzata"
        }
    }
}

// MARK: - ToggleCategory

/// Categoria del feature flag, usata per raggruppare i flag nella dashboard.
enum ToggleCategory: String, CaseIterable, Sendable {
    case release    = "Release"
    case experiment = "Experiment"
    case ops        = "Ops"
    case permission = "Permission"

    /// Simbolo SF Symbols associato alla categoria
    var systemImage: String {
        switch self {
        case .release:    return "rocket"
        case .experiment: return "flask"
        case .ops:        return "wrench.and.screwdriver"
        case .permission: return "lock.shield"
        }
    }

    /// Colore associato alla categoria (nome del colore asset o stringa per Color)
    var colorName: String {
        switch self {
        case .release:    return "systemBlue"
        case .experiment: return "systemPurple"
        case .ops:        return "systemOrange"
        case .permission: return "systemGreen"
        }
    }
}
