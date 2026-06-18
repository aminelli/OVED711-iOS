//
//  UIDemoApp.swift
//  UIDemo
//
//  Punto di ingresso dell'applicazione.
//
//  Inizializza e inietta nell'environment i due oggetti @Observable globali:
//  - AppState: stato UI globale (tab, preferenze, contatore demo)
//  - NavigationRouter: stack di navigazione e deep linking
//
//  L'iniezione tramite .environment() rende questi oggetti accessibili
//  a tutte le view nell'albero senza passarli esplicitamente.
//
//  In Swift 6 con @Observable non è più necessario usare @StateObject /
//  @EnvironmentObject: si usa @State per creare l'istanza nel App
//  e .environment() per iniettarla.
//
//  Riferimento: WWDC 2023 "Discover Observation in SwiftUI"
//

import SwiftUI

@main
struct UIDemoApp: App {

    /// Stato globale dell'applicazione.
    /// @State nel contesto di App garantisce che l'oggetto venga
    /// creato una sola volta per tutto il ciclo di vita dell'app.
    @State private var appState = AppState()

    /// Router per la navigazione e la gestione dei deep link.
    @State private var navigationRouter = NavigationRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inietta AppState nell'environment: accessibile via @Environment(AppState.self)
                .environment(appState)
                // Inietta NavigationRouter: accessibile via @Environment(NavigationRouter.self)
                .environment(navigationRouter)
                // Gestisce i deep link in arrivo dallo schema URL "uidemo://"
                .onOpenURL { url in
                    // Se il deep link viene da un tab diverso da navigation,
                    // naviga prima al tab navigation poi gestisce il link
                    if navigationRouter.handle(url: url) {
                        withAnimation(AppTheme.Animation.standard) {
                            appState.selectedTab = .navigation
                        }
                        appState.showFeedback("Deep link: \(url.host ?? "sconosciuto")")
                    }
                }
        }
    }
}
