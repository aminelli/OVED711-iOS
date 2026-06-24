// HealthKit lettura e scruttura dati passi

import HealthKit
import Foundation

// MARK: - HealthKit Service Actor

actor HealthKitService {
    private let store = HKHealthStore()

    // Tipi
    private let stepType = HKQuantityType(.stepCount)
    private let energyType = HKQuantityType(.activeEnergyBurned)

    // MARK: - Autorizzazione

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        let toRead: Set<HKObjectType> = [stepType, energyType]
        let toShare: Set<HKSampleType> = [stepType, energyType]

        try await store.requestAuthorization(toShare: toShare, read: toRead)
    }

    // MARK: - Lettura passi ultimi 7 giorni (HKStatisticsCollectionQuery)

    func stepsLastSevenDays() async throws -> [Date: Int] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) else {
            throw HealthError.invalidDate
        }

        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: endDate),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }

                var result: [Date: Int] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    result[statistics.startDate] = Int(steps)
                }
                continuation.resume(returning: result)
            }

            store.execute(query)
        }
    }

    // MARK: - Scrittura campione passi

    func writeSteps(_ count: Double, start: Date, end: Date) async throws {
        let quantity = HKQuantity(unit: .count(), doubleValue: count)
        let sample = HKQuantitySample(
            type: stepType,
            quantity: quantity,
            start: start,
            end: end
        )
        try await store.save(sample)
    }
}

// MARK: - Errori

enum HealthError: Error, LocalizedError {
    case notAvailable
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit non disponibile su questo dispositivo"
        case .invalidDate: return "Intervallo di date non valido"
        }
    }
}