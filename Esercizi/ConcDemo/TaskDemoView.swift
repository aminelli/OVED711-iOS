//
//  TaskDemoView.swift
//  ConcDemo
//
//  Dimostra: Task strutturati, Task non strutturati, Task.detached
//

import SwiftUI
import OSLog

// MARK: - ViewModel

/// ViewModel per la demo sui Task strutturati e non strutturati.
/// Marcato @MainActor perché aggiorna direttamente lo stato osservabile dalla UI.
@MainActor
@Observable
final class TaskDemoViewModel {

    // MARK: Stato osservabile

    /// Log degli eventi prodotti dai task, mostrato nella UI
    var log: [String] = []

    /// Indica se un task strutturato è in esecuzione
    var isRunning = false

    // MARK: Errori tipizzati (Swift 6 typed throws)

    enum DemoError: Error {
        case simulatedFailure(String)
    }

    // MARK: - Task strutturato

    /// Esegue un task strutturato tramite async/await.
    /// Il ciclo di vita è legato al contesto chiamante: se la vista sparisce
    /// (e il Task padre viene cancellato), anche questo viene interrotto.
    func runStructuredTask() async {
        isRunning = true
        AppLogger.tasks.info("▶️ Avvio task strutturato")
        append("Task strutturato: avviato")

        // Simulazione lavoro I/O (rete, disco…)
        // Task.sleep è cancellation-aware: lancia CancellationError se cancellato
        try? await Task.sleep(for: .seconds(1))

        append("Task strutturato: completato dopo 1s ✓")
        AppLogger.tasks.info("✅ Task strutturato completato")
        isRunning = false
    }

    // MARK: - Task non strutturato

    /// Avvia un Task non strutturato: il ciclo di vita è indipendente dal contesto.
    /// Utile per operazioni fire-and-forget, ma richiede gestione manuale
    /// della cancellazione e del ritorno su @MainActor.
    func runUnstructuredTask() {
        AppLogger.tasks.info("▶️ Avvio task non strutturato")
        append("Task non strutturato: avviato")

        Task {
            // Questo blocco gira su un executor concorrente
            try? await Task.sleep(for: .seconds(1.5))
            // Ritorno su @MainActor garantito dall'isolamento di `self`
            self.append("Task non strutturato: completato dopo 1.5s ✓")
            AppLogger.tasks.info("✅ Task non strutturato completato")
        }
    }

    // MARK: - Task.detached

    /// Avvia un Task.detached: NON eredita l'executor né i valori di task-local storage.
    /// Ideale per lavoro CPU-intensivo che non deve bloccare @MainActor.
    func runDetachedTask() {
        AppLogger.tasks.info("▶️ Avvio task detached (priority: .background)")
        append("Task detached: avviato su thread separato")

        Task.detached(priority: .background) {
            // Questo codice NON gira su @MainActor
            // Simulazione elaborazione pesante
            try? await Task.sleep(for: .seconds(0.8))

            // Per aggiornare la UI bisogna tornare esplicitamente su @MainActor
            await MainActor.run {
                self.append("Task detached: completato, tornato su MainActor ✓")
                AppLogger.tasks.info("✅ Task detached completato")
            }
        }
    }

    // MARK: - Helper

    private func append(_ message: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        log.append("[\(time)] \(message)")
    }

    func clearLog() { log.removeAll() }
}

// MARK: - View

/// Vista demo per Task strutturati, non strutturati e detached.
struct TaskDemoView: View {

    @State private var viewModel = TaskDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: - Debug tip:
            // Metti un breakpoint all'interno di `runStructuredTask()` e
            // apri Debug → Swift Concurrency in Xcode per vedere il task
            // comparire nell'albero delle sospensioni con il suo executor.

            HStack(spacing: 10) {
                Button("Structured") {
                    Task { await viewModel.runStructuredTask() }
                }
                .disabled(viewModel.isRunning)

                Button("Unstructured") {
                    viewModel.runUnstructuredTask()
                }

                Button("Detached") {
                    viewModel.runDetachedTask()
                }
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isRunning {
                ProgressView("Task strutturato in esecuzione…")
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.log, id: \.self) { entry in
                        Text(entry).font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

            Button("Clear log", role: .destructive) { viewModel.clearLog() }
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Task Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TaskDemoView() }
}
