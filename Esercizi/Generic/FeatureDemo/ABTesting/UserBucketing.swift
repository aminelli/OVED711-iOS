//
//  UserBucketing.swift
//  FeatureDemo
//
//  Algoritmo deterministico di user bucketing per A/B Testing.
//
//  PERCHÉ IL BUCKETING DEVE ESSERE DETERMINISTICO:
//  Un utente deve vedere sempre la stessa variante (A o B) di un esperimento.
//  Se l'assegnazione fosse casuale ad ogni accesso, lo stesso utente vedrebbe
//  varianti diverse in sessioni diverse, rendendo i dati dell'esperimento inutilizzabili.
//
//  ALGORITMO (inspirato a LaunchDarkly e Optimizely):
//  1. Concatena `userID + ":" + flagKey.rawValue` per creare una stringa univoca
//     per la coppia (utente, esperimento)
//  2. Calcola SHA-256 della stringa (hash crittografico, distribuzione uniforme)
//  3. Prendi i primi 4 byte come intero big-endian (UInt32)
//  4. Normalizza il valore a [0.0, 1.0) dividendo per UInt32.max
//  5. Se il valore normalizzato < (rolloutPercentage / 100), l'utente è nel gruppo trattamento
//
//  PROPRIETÀ GARANTITE:
//  - Determinismo: stessa coppia (userID, flagKey) → sempre stesso bucket
//  - Indipendenza: i bucket di esperimenti diversi sono indipendenti (grazie alla concatenazione con flagKey)
//  - Distribuzione uniforme: SHA-256 ha distribuzione uniforme sui suoi output
//  - Scalabilità: nessuno storage necessario, tutto calcolato on-the-fly

import Foundation
import CryptoKit

// MARK: - UserBucketing

/// Motore di bucketing deterministico per esperimenti A/B.
///
/// Tutti i metodi sono statici: non è necessario instanziare questa classe.
/// Thread-safe: usa solo operazioni pure senza stato mutabile.
enum UserBucketing {

    // MARK: - Calcolo del bucket

    /// Calcola il "bucket" normalizzato di un utente per un dato esperimento.
    ///
    /// Il valore risultante è in [0.0, 1.0) ed è sempre identico
    /// per la stessa coppia (userID, flagKey).
    ///
    /// - Parameters:
    ///   - userID: Identificatore univoco dell'utente (es. UUID, hash email)
    ///   - flagKey: Chiave del feature flag dell'esperimento
    /// - Returns: Valore deterministico in [0.0, 1.0)
    static func bucketValue(userID: String, flagKey: FeatureFlagKey) -> Double {
        // Step 1: Crea la stringa di input univoca per la coppia (utente, esperimento)
        // Concatenare flagKey.rawValue garantisce che lo stesso utente abbia
        // bucket diversi per esperimenti diversi (evita correlazione tra esperimenti)
        let input = "\(userID):\(flagKey.rawValue)"

        // Step 2: Calcola SHA-256 — hash crittografico con distribuzione uniforme
        let inputData = Data(input.utf8)
        let hashDigest = SHA256.hash(data: inputData)

        // Step 3: Converti i primi 4 byte dell'hash in UInt32 (big-endian)
        // I primi 4 byte danno 2^32 possibili valori → granularità sufficiente
        let hashBytes = Array(hashDigest)
        let bucketInt = (UInt32(hashBytes[0]) << 24)
                      | (UInt32(hashBytes[1]) << 16)
                      | (UInt32(hashBytes[2]) << 8)
                      |  UInt32(hashBytes[3])

        // Step 4: Normalizza a [0.0, 1.0)
        // Dividiamo per UInt32.max + 1 per ottenere un intervallo aperto in 1.0
        return Double(bucketInt) / (Double(UInt32.max) + 1.0)
    }

    // MARK: - Assegnazione a varianti

    /// Determina se un utente è nel gruppo "trattamento" (variante attiva) dell'esperimento.
    ///
    /// - Parameters:
    ///   - userID: Identificatore univoco dell'utente
    ///   - flagKey: Chiave del feature flag dell'esperimento
    ///   - rolloutPercentage: Percentuale di utenti nel gruppo trattamento [0.0, 100.0]
    /// - Returns: `true` se l'utente deve vedere la variante trattamento
    static func isInTreatmentGroup(
        userID: String,
        flagKey: FeatureFlagKey,
        rolloutPercentage: Double
    ) -> Bool {
        guard rolloutPercentage > 0 else { return false }    // 0% → nessuno nel trattamento
        guard rolloutPercentage < 100 else { return true }   // 100% → tutti nel trattamento

        let bucket = bucketValue(userID: userID, flagKey: flagKey)
        // L'utente è nel trattamento se il suo bucket cade sotto la soglia del rollout
        return bucket < (rolloutPercentage / 100.0)
    }

    /// Assegna l'utente a una delle varianti di un esperimento multi-variante.
    ///
    /// Esempio di uso per un test a 3 varianti (40% / 30% / 30%):
    /// ```swift
    /// let variant = UserBucketing.assignVariant(
    ///     userID: "user-123",
    ///     flagKey: .et_checkoutButtonColor,
    ///     variants: [
    ///         (variant: "control",     weight: 0.40),
    ///         (variant: "treatment_a", weight: 0.30),
    ///         (variant: "treatment_b", weight: 0.30)
    ///     ]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - userID: Identificatore univoco dell'utente
    ///   - flagKey: Chiave del feature flag dell'esperimento
    ///   - variants: Array di (variante, peso). I pesi DEVONO sommare a 1.0.
    /// - Returns: La variante assegnata, o `nil` se l'array è vuoto
    static func assignVariant<T: Sendable>(
        userID: String,
        flagKey: FeatureFlagKey,
        variants: [(variant: T, weight: Double)]
    ) -> T? {
        guard !variants.isEmpty else { return nil }

        // Validazione: i pesi devono sommare a 1.0 (con tolleranza floating point)
        let totalWeight = variants.map(\.weight).reduce(0, +)
        guard abs(totalWeight - 1.0) < 0.001 else {
            // Pesi non validi: usa la prima variante come fallback sicuro
            return variants.first?.variant
        }

        let bucket = bucketValue(userID: userID, flagKey: flagKey)

        // Scansione sequenziale delle varianti per trovare quella corrispondente al bucket
        var cumulativeWeight = 0.0
        for (variant, weight) in variants {
            cumulativeWeight += weight
            if bucket < cumulativeWeight {
                return variant
            }
        }

        // Fallback per errori di arrotondamento floating point
        return variants.last?.variant
    }

    // MARK: - Strumenti di analisi (utili per la dashboard di debug)

    /// Calcola la distribuzione percentuale teorica su un insieme di userID simulati.
    ///
    /// Permette di verificare empiricamente l'uniformità del bucketing
    /// per un dato flag e un dato insieme di utenti simulati.
    ///
    /// - Parameters:
    ///   - flagKey: Chiave del flag da analizzare
    ///   - rolloutPercentage: Percentuale di rollout target
    ///   - sampleSize: Numero di utenti simulati (maggiore = più accurato)
    /// - Returns: La percentuale effettiva di utenti nel gruppo trattamento
    static func simulatedTreatmentRate(
        flagKey: FeatureFlagKey,
        rolloutPercentage: Double,
        sampleSize: Int = 1000
    ) -> Double {
        let treatmentCount = (0..<sampleSize).filter { i in
            isInTreatmentGroup(
                userID: "simulated-user-\(i)",
                flagKey: flagKey,
                rolloutPercentage: rolloutPercentage
            )
        }.count

        return Double(treatmentCount) / Double(sampleSize) * 100.0
    }
}
