//
//  ActorDemoView.swift
//  ConcDemo
//
//  Dimostra: actor, @MainActor, nonisolated
//

import SwiftUI
import OSLog

// MARK: - Actor

/// Contatore thread-safe implementato come actor Swift.
/// L'actor garantisce che un solo task alla volta acceda allo stato interno,
/// eliminando le data race senza lock manuali né DispatchQueue.
actor SafeCounter {

    // MARK: Stato privato all'actor

    /// Valore corrente del contatore
    private(set) var value: Int = 0

    /// Storico degli incrementi con timestamp
    private(set) var history: [String] = []

    // MARK: Interfaccia pubblica

    /// Incrementa il contatore. Richiede `await` dall'esterno perché accede
    /// allo stato isolato: il chiamante viene sospeso finché l'actor è libero.
    func increment(by amount: Int = 1) {
        value += amount
        let entry = "+\(amount) → \(value)"
        history.append(entry)
        AppLogger.actors.debug("SafeCounter: \(entry)")
    }

    /// Reimposta il contatore a zero.
    func reset() {
        value = 0
        history.removeAll()
        AppLogger.actors.info("SafeCounter: reset")
    }

    // MARK: nonisolated

    /// Metodo nonisolated: non richiede hop all'actor executor.
    /// Usato per proprietà o metodi che non dipendono dallo stato isolato.
    /// NOTA: da qui NON si può accedere a `value` o `history`.
    nonisolated var label: String { "SafeCounter (actor)" }
}

// MARK: - ViewModel

/// ViewModel per la demo sugli attori.
@MainActor
@Observable
final class ActorDemoViewModel {

    // MARK: Stato UI

    var displayValue: Int = 0
    var history: [String] = []
    var isRunning = false

    // MARK: Actor privato

    /// Istanza condivisa tra tutti i task concorrenti
    private let counter = SafeCounter()

    // MARK: - Demo: incrementi concorrenti

    /// Lancia 10 task in parallelo che incrementano lo stesso counter.
    /// Grazie all'actor, ogni hop è serializzato: nessuna data race.
    func runConcurrentIncrements() async {
        isRunning = true
        await counter.reset()
        AppLogger.actors.info("▶️ Avvio 10 incrementi concorrenti")

        // MARK: - Debug tip:
        // Abilita Thread Sanitizer (Product → Scheme → Edit Scheme →
        // Diagnostics → Thread Sanitizer) e osserva che NON vengono
        // segnalate data race grazie all'isolamento dell'actor.

        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    // Ogni accesso è serializzato dall'actor executor
                    await self.counter.increment(by: i)
                }
            }
        }

        // Recupera lo stato finale: richiede `await` perché è dati isolati
        displayValue = await counter.value
        history = await counter.history

        AppLogger.actors.info("✅ Valore finale (atteso 55): \(self.displayValue)")
        isRunning = false
    }
}

// MARK: - View

struct ActorDemoView: View {

    @State private var viewModel = ActorDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                VStack(alignment: .leading) {
                    Text("Valore finale")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.displayValue)")
                        .font(.title.bold().monospacedDigit())
                }
                Spacer()
                Button("Avvia 10 task") {
                    Task { await viewModel.runConcurrentIncrements() }
                }
                .disabled(viewModel.isRunning)
                .buttonStyle(.borderedProminent)
            }

            Text("(risultato atteso: 1+2+…+10 = 55)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.isRunning {
                ProgressView("Incrementi in corso…")
            }

            Divider()

            Text("Storico incrementi (ordine di esecuzione)").font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.history, id: \.self) { entry in
                        Text(entry).font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Actor Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ActorDemoView() }
}
