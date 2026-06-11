//
//  ContinuationDemoView.swift
//  ConcDemo
//
//  Dimostra: withCheckedContinuation, withCheckedThrowingContinuation
//  Bridge da API callback-based (legacy/Objective-C) a async/await.
//

import SwiftUI
import OSLog

// MARK: - Servizio legacy (callback-based)

/// Simula un servizio scritto con completion handler, come spesso si trova
/// in SDK legacy o codice Objective-C non ancora migrato ad async/await.
final class LegacyDataService: @unchecked Sendable {

    enum LegacyError: Error, LocalizedError {
        case serviceUnavailable

        var errorDescription: String? { "Servizio non disponibile (id non valido)" }
    }

    /// Metodo sincrono con completion handler — non async.
    /// Risponde su una coda background dopo circa 1 secondo.
    func fetchData(id: Int, completion: @escaping (Result<String, LegacyError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            if id > 0 {
                completion(.success("Dati per ID \(id) (da servizio legacy)"))
            } else {
                completion(.failure(.serviceUnavailable))
            }
        }
    }
}

// MARK: - Bridge async/await tramite continuazioni

extension LegacyDataService {

    /// Versione async del metodo fetchData.
    ///
    /// `withCheckedThrowingContinuation` sospende il task corrente e lo riprende
    /// esattamente quando viene chiamato `continuation.resume(...)`.
    ///
    /// - Important: `resume` DEVE essere chiamato esattamente una volta.
    ///   Zero chiamate → il task rimane sospeso per sempre (memory leak).
    ///   Più di una → crash a runtime (asserzione del runtime Swift).
    func fetchDataAsync(id: Int) async throws -> String {
        // MARK: - Debug tip:
        // Metti un breakpoint su `continuation.resume(returning:)` e osserva
        // nella vista "Swift Concurrency" di Xcode come il task viene
        // "risvegliato" non appena la completion handler viene chiamata.
        try await withCheckedThrowingContinuation { continuation in
            self.fetchData(id: id) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ContinuationDemoViewModel {

    var result: String = ""
    var isLoading = false
    var errorMessage: String?

    private let service = LegacyDataService()

    // MARK: Fetch con successo

    func fetchValid() async {
        isLoading = true
        result = ""
        errorMessage = nil
        AppLogger.continuations.info("▶️ Richiesta valida (id=1)")

        do {
            let data = try await service.fetchDataAsync(id: 1)
            result = data
            AppLogger.continuations.info("✅ Ricevuto: \(data)")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: Fetch con errore

    func fetchInvalid() async {
        isLoading = true
        result = ""
        errorMessage = nil
        AppLogger.continuations.info("▶️ Richiesta non valida (id=-1)")

        do {
            let data = try await service.fetchDataAsync(id: -1)
            result = data
        } catch let error as LegacyDataService.LegacyError {
            errorMessage = error.localizedDescription
            AppLogger.continuations.error("❌ \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.continuations.error("❌ Errore inatteso: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - View

struct ContinuationDemoView: View {

    @State private var viewModel = ContinuationDemoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 12) {
                Button("Fetch valido (id=1)") {
                    Task { await viewModel.fetchValid() }
                }
                .disabled(viewModel.isLoading)

                Button("Fetch non valido (id=-1)") {
                    Task { await viewModel.fetchInvalid() }
                }
                .disabled(viewModel.isLoading)
                .tint(.orange)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isLoading {
                ProgressView("In attesa del servizio legacy…")
            }

            if !viewModel.result.isEmpty {
                Label(viewModel.result, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let err = viewModel.errorMessage {
                Label(err, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            Divider()

            Text("Note tecniche")
                .font(.headline)

            Text("""
                withCheckedThrowingContinuation "avvolge" la vecchia API callback \
                in un'interfaccia async/await, senza riscrivere il servizio legacy. \
                Il runtime Swift verifica a runtime che resume() venga chiamato \
                esattamente una volta (il prefisso "Checked" garantisce questo).
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Continuation Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ContinuationDemoView() }
}
