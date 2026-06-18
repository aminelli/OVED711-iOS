//
//  CancellationDemoView.swift
//  ConcDemo
//
//  Dimostra: Task.checkCancellation(), Task.isCancelled, cancellazione cooperativa
//

import SwiftUI
import OSLog

// MARK: - ViewModel

@MainActor
@Observable
final class CancellationDemoViewModel {

    // MARK: Stato

    var log: [String] = []
    var isRunning = false

    private var currentTask: Task<Void, Never>?

    // MARK: - Metodo 1: checkCancellation (lancia CancellationError)

    /// Avvia un lavoro suddiviso in 10 step.
    /// Ogni step chiama `try Task.checkCancellation()` che lancia
    /// CancellationError se il task è stato cancellato, interrompendo
    /// il flusso in modo pulito con un blocco catch.
    func startWorkWithCheckCancellation() {
        guard !isRunning else { return }
        isRunning = true
        log.removeAll()
        AppLogger.cancellation.info("▶️ Lavoro avviato (checkCancellation)")

        currentTask = Task {
            do {
                for step in 1...10 {
                    // Verifica la cancellazione prima di ogni step
                    // Lancia CancellationError se il task è stato cancellato
                    try Task.checkCancellation()

                    append("Step \(step)/10 — avviato")

                    // Task.sleep è cancellation-aware: lancia CancellationError
                    // al prossimo await se il task è stato cancellato
                    try await Task.sleep(for: .milliseconds(600))

                    append("Step \(step)/10 — completato ✓")
                }
                append("🎉 Lavoro completato con successo!")
                AppLogger.cancellation.info("✅ Completato")
            } catch is CancellationError {
                // MARK: - Debug tip:
                // Metti un breakpoint qui per vedere a quale step è avvenuta
                // la cancellazione. In Xcode, la backtrace mostrerà il punto
                // esatto dove `Task.sleep` o `checkCancellation` ha rilanciato.
                append("⚠️ Cancellato al passo corrente (CancellationError)")
                AppLogger.cancellation.warning("⚠️ Cancellato")
            } catch {
                // Catch generico necessario per rendere il Task non-throwing (Task<Void, Never>)
                // In questa demo non ci sono altri errori possibili, ma il compilatore
                // Swift 6 richiede che tutti i percorsi throwing siano coperti.
                append("❌ Errore inatteso: \(error)")
                AppLogger.cancellation.error("❌ Errore inatteso: \(error.localizedDescription)")
            }
            isRunning = false
        }
    }

    // MARK: - Metodo 2: Task.isCancelled (polling esplicito)

    /// Variante con polling: non lancia errori, ma controlla `Task.isCancelled`
    /// ad ogni iterazione. Utile in loop CPU-bound dove non è possibile usare
    /// `await` intermedi oppure si vuole completare lo step prima di fermarsi.
    func startWorkWithPolling() {
        guard !isRunning else { return }
        isRunning = true
        log.removeAll()
        AppLogger.cancellation.info("▶️ Lavoro avviato (isCancelled polling)")

        currentTask = Task.detached(priority: .userInitiated) {
            var step = 0
            // Il loop si interrompe non appena viene rilevata la cancellazione
            while !Task.isCancelled && step < 10 {
                step += 1
                // Simulazione step con await (anche qui rispetta la cancellazione)
                try? await Task.sleep(for: .milliseconds(500))

                await MainActor.run {
                    self.append("Polling step \(step)/10 ✓")
                }
            }
            await MainActor.run {
                if Task.isCancelled {
                    self.append("🔴 Interrotto dopo il passo \(step) (isCancelled=true)")
                    AppLogger.cancellation.warning("⚠️ Polling interrotto al passo \(step)")
                } else {
                    self.append("🎉 Polling completato (\(step) passi)")
                    AppLogger.cancellation.info("✅ Polling completato")
                }
                self.isRunning = false
            }
        }
    }

    // MARK: - Cancellazione

    /// Richiede la cancellazione del task corrente.
    /// La cancellazione è COOPERATIVA: il task si accorge solo al prossimo
    /// `try Task.checkCancellation()` o alla prossima `await` su API cancellation-aware.
    func cancelWork() {
        currentTask?.cancel()
        append("🔴 Cancellazione richiesta (il task si fermerà al prossimo check)")
        AppLogger.cancellation.info("🔴 Cancellazione richiesta dall'utente")
    }

    // MARK: Helper

    private func append(_ message: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        log.append("[\(time)] \(message)")
    }
}

// MARK: - View

struct CancellationDemoView: View {

    @State private var viewModel = CancellationDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 10) {
                Button("checkCancellation") {
                    viewModel.startWorkWithCheckCancellation()
                }
                .disabled(viewModel.isRunning)

                Button("isCancelled polling") {
                    viewModel.startWorkWithPolling()
                }
                .disabled(viewModel.isRunning)
            }
            .buttonStyle(.borderedProminent)

            Button("Cancella ora", role: .destructive) {
                viewModel.cancelWork()
            }
            .disabled(!viewModel.isRunning)
            .buttonStyle(.bordered)

            if viewModel.isRunning {
                ProgressView("In esecuzione…")
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
        }
        .padding()
        .navigationTitle("Cancellazione Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CancellationDemoView() }
}
