//
//  AppState.swift
//  UIDemo
//
//  Stato globale dell'applicazione gestito con il macro @Observable (iOS 17+).
//  @Observable è il sostituto moderno di ObservableObject:
//  - Traccia automaticamente le proprietà accedute nella view
//  - Elimina il boilerplate di @Published
//  - Supporta la concorrenza Swift 6 tramite @MainActor
//
//  Riferimento: WWDC 2023 "Discover Observation in SwiftUI"
//

import SwiftUI
import Observation

// MARK: - Modello utente

/// Rappresenta il profilo dell'utente corrente nell'applicazione.
struct UserProfile: Equatable {
    var id: UUID = UUID()
    var name: String = "Ospite"
    var avatarSystemName: String = "person.circle.fill"
    var isPremium: Bool = false
    var preferredColorScheme: ColorScheme? = nil
}

// MARK: - AppState

/// Stato globale dell'applicazione, condiviso tramite l'environment SwiftUI.
/// Annotato con @MainActor per garantire che tutte le modifiche avvengano
/// sul thread principale, evitando data race in Swift 6.
@Observable
@MainActor
final class AppState {

    // MARK: - Profilo utente
    /// Profilo dell'utente autenticato (o ospite)
    var userProfile: UserProfile = UserProfile()

    // MARK: - Preferenze UI
    /// Attiva/disattiva gli effetti LiquidGlass in tutta l'app
    var glassEffectsEnabled: Bool = true
    /// Attiva/disattiva le animazioni (accessibilità: Reduce Motion)
    var animationsEnabled: Bool = true
    /// Schema colori preferito dall'utente
    var preferredColorScheme: ColorScheme? = nil

    // MARK: - Navigazione
    /// Mantiene il tab attualmente selezionato nella TabView principale
    var selectedTab: AppTab = .home
    /// Flag per mostrare un foglio modale globale (es. onboarding, notifiche)
    var showGlobalSheet: Bool = false
    /// Messaggio di feedback globale (es. toast/banner)
    var feedbackMessage: String? = nil

    // MARK: - Contatori demo
    /// Contatore globale usato negli esempi di state management
    var globalCounter: Int = 0

    // MARK: - Metodi

    /// Incrementa il contatore globale con animazione.
    func incrementCounter() {
        withAnimation(AppTheme.Animation.fast) {
            globalCounter += 1
        }
    }

    /// Resetta l'intera sessione demo.
    func resetDemo() {
        withAnimation(AppTheme.Animation.standard) {
            globalCounter = 0
            feedbackMessage = nil
        }
    }

    /// Mostra un messaggio di feedback temporaneo (simile a un toast).
    /// Il messaggio scompare automaticamente dopo 2 secondi.
    func showFeedback(_ message: String) {
        feedbackMessage = message
        // Task strutturato: attende 2 secondi e poi rimuove il messaggio
        Task {
            try? await Task.sleep(for: .seconds(2))
            feedbackMessage = nil
        }
    }
}

// MARK: - AppTab Enum

/// Identifica i tab principali della navigazione a tab.
/// Conformità a String per supportare deep linking via URL scheme.
enum AppTab: String, CaseIterable, Identifiable {
    case home          = "home"
    case hybrid        = "hybrid"
    case stateDemo     = "state"
    case navigation    = "navigation"
    case gestures      = "gestures"
    case accessibility = "accessibility"
    case liquidGlass   = "glass"
    case designSystem  = "design"

    var id: String { rawValue }

    /// Titolo localizzabile per il tab
    var title: String {
        switch self {
        case .home:          return "Home"
        case .hybrid:        return "Hybrid UI"
        case .stateDemo:     return "State"
        case .navigation:    return "Navigation"
        case .gestures:      return "Gestures"
        case .accessibility: return "A11y"
        case .liquidGlass:   return "Glass"
        case .designSystem:  return "Design"
        }
    }

    /// Icona SF Symbols per il tab
    var systemImage: String {
        switch self {
        case .home:          return "house.fill"
        case .hybrid:        return "rectangle.split.2x1.fill"
        case .stateDemo:     return "waveform.path"
        case .navigation:    return "map.fill"
        case .gestures:      return "hand.draw.fill"
        case .accessibility: return "accessibility"
        case .liquidGlass:   return "drop.fill"
        case .designSystem:  return "paintbrush.fill"
        }
    }
}
