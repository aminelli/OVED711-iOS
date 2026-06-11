//
//  FeatureDemoApp.swift
//  FeatureDemo
//
//  Created by Antonio Minelli.
//
//  Entry point dell'applicazione.
//
//  GESTIONE DEL COLD START:
//  L'app mostra subito la ContentView con valori di fallback (istantanei).
//  In background, `.task {}` avvia il bootstrap asincrono che:
//    1. Applica gli override compile-time per l'ambiente di sviluppo
//    2. Configura le strategie di rollout lato client
//    3. Esegue il fetch della configurazione remota (Firebase simulato)
//    4. Aggiorna la UI con i nuovi valori — senza bloccare il lancio dell'app
//
//  DISTRIBUZIONE DELLE DIPENDENZE:
//  `AppDependencies` viene creata una sola volta e distribuita a tutta la
//  gerarchia di View tramite `.environment()`. Le View la accedono con
//  `@Environment(AppDependencies.self)` senza passaggi espliciti di parametri.

import SwiftUI

@main
struct FeatureDemoApp: App {

    /// Contenitore centrale delle dipendenze — una sola istanza per tutta l'app
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inietta le dipendenze in tutta la gerarchia di View
                .environment(dependencies)
                // Bootstrap asincrono: eseguito una sola volta dopo il lancio
                // La UI è già visibile durante il bootstrap (cold start gestito)
                .task {
                    await dependencies.bootstrap()
                }
        }
    }
}
