//
//  TaskGroupDemoView.swift
//  ConcDemo
//
//  Dimostra: withTaskGroup, withThrowingTaskGroup
//

import SwiftUI
import OSLog

// MARK: - ViewModel

/// ViewModel per la demo sui gruppi di task.
/// withTaskGroup esegue N task in parallelo raccogliendo i risultati
/// in modo strutturato (tutti i figli completano prima del return).
@MainActor
@Observable
final class TaskGroupDemoViewModel {

    // MARK: Stato

    var results: [String] = []
    var isRunning = false
    var errorMessage: String?

    // MARK: Errori tipizzati (Swift 6)

    enum FetchError: Error, LocalizedError {
        case networkTimeout(Int)
        case invalidData(Int)

        var errorDescription: String? {
            switch self {
            case .networkTimeout(let id): return "Timeout sulla richiesta \(id)"
            case .invalidData(let id):   return "Dati non validi dalla richiesta \(id)"
            }
        }
    }

    // MARK: - withTaskGroup (senza errori)

    /// Scarica 5 "risorse" in parallelo raccogliendo i risultati man mano.
    /// L'ordine di arrivo dipende dalla latenza simulata, non dall'ordine di lancio.
    func runParallelFetch() async {
        isRunning = true
        results.removeAll()
        errorMessage = nil
        AppLogger.groups.info("▶️ Avvio fetch parallelo (5 risorse)")

        await withTaskGroup(of: String.self) { group in
            for id in 1...5 {
                // Ogni addTask aggiunge un task figlio al gruppo
                group.addTask {
                    let delay = Double.random(in: 0.3...1.5)
                    try? await Task.sleep(for: .seconds(delay))
                    AppLogger.groups.debug("📦 Risorsa \(id) pronta in \(delay, format: .fixed(precision: 2))s")
                    return "Risorsa \(id) — \(String(format: "%.2f", delay))s"
                }
            }
            // I risultati arrivano nell'ordine di completamento
            for await result in group {
                results.append(result)
            }
        }

        AppLogger.groups.info("✅ Fetch completato: \(self.results.count) risultati")
        isRunning = false
    }

    // MARK: - withThrowingTaskGroup (con errore)

    /// Come sopra, ma la richiesta con id=3 simula un timeout.
    /// Al primo errore il gruppo annulla automaticamente i task rimanenti.
    func runParallelFetchWithError() async {
        isRunning = true
        results.removeAll()
        errorMessage = nil
        AppLogger.groups.info("▶️ Avvio fetch parallelo con errore simulato su id=3")

        do {
            try await withThrowingTaskGroup(of: String.self) { group in
                for id in 1...5 {
                    group.addTask {
                        let delay = Double.random(in: 0.3...1.0)
                        try await Task.sleep(for: .seconds(delay))

                        // MARK: - Debug tip:
                        // Metti un breakpoint su questa riga e osserva nella vista
                        // "Swift Concurrency" di Xcode come il task id=3 lancia
                        // l'errore e i task fratelli vengono cancellati.
                        if id == 3 {
                            throw FetchError.networkTimeout(id)
                        }
                        return "Risorsa \(id) OK"
                    }
                }
                for try await result in group {
                    results.append(result)
                }
            }
        } catch let error as FetchError {
            errorMessage = error.localizedDescription
            AppLogger.groups.error("❌ Errore nel gruppo: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
        }

        isRunning = false
    }
}

// MARK: - View

struct TaskGroupDemoView: View {

    @State private var viewModel = TaskGroupDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 12) {
                Button("Fetch parallelo") {
                    Task { await viewModel.runParallelFetch() }
                }
                .disabled(viewModel.isRunning)

                Button("Con errore") {
                    Task { await viewModel.runParallelFetchWithError() }
                }
                .disabled(viewModel.isRunning)
                .tint(.orange)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isRunning {
                ProgressView("Task in esecuzione…")
            }

            if let err = viewModel.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.results, id: \.self) { item in
                        Text(item).font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("TaskGroup Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TaskGroupDemoView() }
}
