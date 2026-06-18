//
//  ContentView.swift
//  FeatureDemo
//
//  Created by Antonio Minelli.
//
//  ContentView è il punto di ingresso della UI.
//  Implementa un TabView con tre sezioni:
//    1. Home — mostra i feature flag in azione nella UI reale
//    2. A/B Testing — demo interattiva dell'algoritmo di bucketing
//    3. Dashboard — pannello di debug per gestire gli override dei flag (solo DEBUG/STAGING)

import SwiftUI

struct ContentView: View {

    // Accede al contenitore delle dipendenze iniettato da FeatureDemoApp
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        TabView {

            // MARK: Tab 1 — Home (feature flag in produzione)
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // MARK: Tab 2 — A/B Testing Demo
            ABTestingDemoView()
                .tabItem {
                    Label("A/B Testing", systemImage: "flask.fill")
                }

            // MARK: Tab 3 — Dashboard di debug (solo in DEBUG/STAGING)
            // In produzione questa sezione non è inclusa nel binario grazie a #if
            #if DEBUG || STAGING
            FeatureFlagDashboardView()
                .tabItem {
                    Label("Debug", systemImage: "wrench.and.screwdriver.fill")
                }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(AppDependencies())
}
