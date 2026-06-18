//
//  AsyncStreamDemoView.swift
//  ConcDemo
//
//  Dimostra: AsyncStream, AsyncThrowingStream
//

import SwiftUI
import OSLog

// MARK: - Produttore sensore (AsyncStream)

/// Simula un sensore di temperatura che emette letture a intervalli regolari.
/// AsyncStream è preferito a combine per flussi semplici e lineari.
struct SensorProducer {

    struct Reading: Identifiable {
        let id = UUID()
        let value: Double
        let timestamp: Date
    }

    /// Restituisce un AsyncStream di letture.
    /// Il flusso continua finché il consumatore non cancella il Task che lo consuma.
    static func readings(interval: Duration = .seconds(0.5)) -> AsyncStream<Reading> {
        AsyncStream { continuation in
            let producerTask = Task {
                var index = 0
                // Il loop si interrompe quando il Task viene cancellato
                while !Task.isCancelled {
                    let reading = Reading(
                        value: Double.random(in: 20.0...30.0),
                        timestamp: .now
                    )
                    AppLogger.streams.debug("📡 Lettura \(index): \(reading.value, format: .fixed(precision: 2))°C")
                    // Yield emette il valore nello stream senza bloccare il produttore
                    continuation.yield(reading)
                    index += 1
                    try? await Task.sleep(for: interval)
                }
                // Segnala che lo stream è terminato
                continuation.finish()
                AppLogger.streams.info("🔴 Stream terminato dopo \(index) letture")
            }
            // onTermination viene chiamato quando il consumatore abbandona il for-await
            continuation.onTermination = { _ in
                producerTask.cancel()
            }
        }
    }
}

// MARK: - Produttore rete (AsyncThrowingStream)

/// Simula un flusso di eventi di rete che può interrompersi con un errore.
struct NetworkEventProducer {

    enum NetworkError: Error, LocalizedError {
        case connectionLost
        var errorDescription: String? { "Connessione persa" }
    }

    /// Stream che emette eventi fino a `limit`, poi lancia un errore.
    static func events(failAfter limit: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for i in 1...20 {
                    guard !Task.isCancelled else { break }
                    try? await Task.sleep(for: .milliseconds(400))

                    if i > limit {
                        // MARK: - Debug tip:
                        // Breakpoint qui: osserva come l'errore propagato dallo stream
                        // viene catturato nel `for try await` del consumatore.
                        continuation.finish(throwing: NetworkError.connectionLost)
                        return
                    }
                    continuation.yield("Evento rete #\(i)")
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class AsyncStreamDemoViewModel {

    // MARK: Stato sensore
    var sensorReadings: [SensorProducer.Reading] = []
    var isSensorActive = false
    private var sensorTask: Task<Void, Never>?

    // MARK: Stato rete
    var networkEvents: [String] = []
    var networkError: String?
    var isNetworkActive = false
    private var networkTask: Task<Void, Never>?

    // MARK: Sensore

    func startSensor() {
        guard !isSensorActive else { return }
        isSensorActive = true
        sensorReadings.removeAll()
        AppLogger.streams.info("▶️ Sensore avviato")

        sensorTask = Task {
            for await reading in SensorProducer.readings() {
                sensorReadings.append(reading)
                // Mantieni solo le ultime 15 letture per non saturare la UI
                if sensorReadings.count > 15 {
                    sensorReadings.removeFirst()
                }
            }
            isSensorActive = false
        }
    }

    func stopSensor() {
        sensorTask?.cancel()
        sensorTask = nil
        isSensorActive = false
        AppLogger.streams.info("⏹ Sensore fermato")
    }

    // MARK: Rete

    func startNetworkStream(failAfter limit: Int) {
        networkTask?.cancel()
        networkEvents.removeAll()
        networkError = nil
        isNetworkActive = true
        AppLogger.streams.info("▶️ Stream rete avviato (failAfter=\(limit))")

        networkTask = Task {
            do {
                for try await event in NetworkEventProducer.events(failAfter: limit) {
                    networkEvents.append(event)
                }
            } catch {
                networkError = "Stream interrotto: \(error.localizedDescription)"
                AppLogger.streams.error("❌ \(error.localizedDescription)")
            }
            isNetworkActive = false
        }
    }
}

// MARK: - View

struct AsyncStreamDemoView: View {

    @State private var viewModel = AsyncStreamDemoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: Sensore
                GroupBox {
                    HStack {
                        Text("Sensore temperatura")
                            .font(.headline)
                        Spacer()
                        if viewModel.isSensorActive {
                            ProgressView().scaleEffect(0.7)
                        }
                        Button(viewModel.isSensorActive ? "Stop" : "Start") {
                            if viewModel.isSensorActive {
                                viewModel.stopSensor()
                            } else {
                                viewModel.startSensor()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isSensorActive ? .red : .green)
                    }
                    Divider()
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.sensorReadings) { r in
                            Text(String(
                                format: "%.2f°C  %@",
                                r.value,
                                r.timestamp.formatted(date: .omitted, time: .standard)
                            ))
                            .font(.caption.monospaced())
                        }
                    }
                }

                // MARK: Rete
                GroupBox {
                    HStack {
                        Text("Stream di rete")
                            .font(.headline)
                        Spacer()
                        if viewModel.isNetworkActive {
                            ProgressView().scaleEffect(0.7)
                        }
                    }
                    HStack(spacing: 10) {
                        Button("Fail dopo 3") {
                            viewModel.startNetworkStream(failAfter: 3)
                        }
                        Button("Fail dopo 7") {
                            viewModel.startNetworkStream(failAfter: 7)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isNetworkActive)
                    .padding(.vertical, 4)

                    if let err = viewModel.networkError {
                        Label(err, systemImage: "wifi.slash")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.networkEvents, id: \.self) { e in
                            Text(e).font(.caption.monospaced())
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AsyncStream Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AsyncStreamDemoView() }
}
