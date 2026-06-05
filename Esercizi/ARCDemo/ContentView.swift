//
//  ContentView.swift
//  ARCDemo
//
//  Created by Antonio Minelli on 04/06/2026.
//
//  Punto di ingresso della demo ARC.
//  Ogni voce della lista naviga verso uno scenario distinto che illustra
//  un aspetto specifico di Automatic Reference Counting in Swift 6.3.
//

import SwiftUI

// MARK: - Modello di navigazione

/// Rappresenta un singolo scenario della demo ARC.
private struct ARCScenario: Identifiable {
    let id = UUID()
    /// Titolo mostrato nella lista.
    let title: String
    /// Icona SF Symbols associata allo scenario.
    let icon: String
    /// Colore identificativo.
    let color: Color
    /// Breve descrizione del concetto trattato.
    let subtitle: String
}

// MARK: - ContentView

/// Vista principale: lista di navigazione verso i quattro scenari ARC.
struct ContentView: View {

    /// Scenari disponibili, in ordine didattico crescente di complessità.
    private let scenarios: [ARCScenario] = [
        ARCScenario(
            title: "Strong Reference",
            icon: "link",
            color: .red,
            subtitle: "Retain cycle tra due classi con riferimenti forti reciproci"
        ),
        ARCScenario(
            title: "Weak Reference",
            icon: "link.badge.minus",
            color: .blue,
            subtitle: "Soluzione al retain cycle con riferimento debole opzionale"
        ),
        ARCScenario(
            title: "Unowned Reference",
            icon: "arrow.triangle.2.circlepath",
            color: .orange,
            subtitle: "Riferimento non-opzionale quando il ciclo di vita è garantito"
        ),
        ARCScenario(
            title: "Closure Capture",
            icon: "curlybraces",
            color: .purple,
            subtitle: "Capture list [weak self] e [unowned self] nelle closure"
        )
    ]

    var body: some View {
        NavigationStack {
            List(scenarios) { scenario in
                NavigationLink {
                    // Destinazione basata sul titolo dello scenario
                    destinationView(for: scenario.title)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title)
                                .font(.headline)
                            Text(scenario.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: scenario.icon)
                            .foregroundStyle(scenario.color)
                            .frame(width: 28)
                    }
                }
            }
            .navigationTitle("ARC Demo")
            .navigationSubtitle("Swift 6.3 · iOS 26")
        }
    }

    // MARK: - Routing

    /// Restituisce la view di destinazione corretta per ogni scenario.
    @ViewBuilder
    private func destinationView(for title: String) -> some View {
        switch title {
        case "Strong Reference":
            StrongReferenceDemo()
        case "Weak Reference":
            WeakReferenceDemo()
        case "Unowned Reference":
            UnownedReferenceDemo()
        case "Closure Capture":
            ClosureCaptureDemo()
        default:
            // Fallback che non dovrebbe mai essere raggiunto
            Text("Scenario non trovato")
        }
    }
}

#Preview {
    ContentView()
}
