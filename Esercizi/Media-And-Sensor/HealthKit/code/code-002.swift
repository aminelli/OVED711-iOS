// Pedometer example

import CoreMotion
import Foundation

// MARK: - Pedometer Service

actor PedometerService {
    private let pedometer = CMPedometer()

    // MARK: - Streaming live

    func startLive() throws -> AsyncStream<CMPedometerData> {
        guard CMPedometer.isStepCountingAvailable() else { throw MotionError.unavailable }

        var cont: AsyncStream<CMPedometerData>.Continuation!
        let stream = AsyncStream<CMPedometerData>(bufferingPolicy: .bufferingNewest(20)) { cont = $0 }

        pedometer.startUpdates(from: Date()) { data, error in
            guard let data, error == nil else { return }
            cont.yield(data)
        }

        return stream
    }

    func stop() {
        pedometer.stopUpdates()
    }

    // MARK: - Query storica

    func querySteps(from start: Date, to end: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }
}


// MARK: - ViewModel

@Observable @MainActor
final class PedometerViewModel {
    var steps: Int = 0
    var distance: Double = 0
    var cadence: Double = 0
    private let service = PedometerService()

    func start() async {
        do {
            let stream = try await service.startLive()
            Task {
                for await data in stream {
                    self.steps = data.numberOfSteps.intValue
                    self.distance = data.distance?.doubleValue ?? 0
                    self.cadence = data.currentCadence?.doubleValue ?? 0
                }
            }
        } catch {
            print("Pedometro non disponibile: \(error)")
        }
    }
}