//
//  ABTestingDemoView.swift
//  FeatureDemo
//
//  Schermata dimostrativa dell'algoritmo di user bucketing per A/B Testing.
//
//  Questa view permette di esplorare interattivamente:
//    - Come l'algoritmo di bucketing assegna gli utenti alle varianti
//    - L'effetto del rollout percentuale sulla distribuzione
//    - La distribuzione empirica su un campione simulato di utenti
//    - L'indipendenza tra esperimenti diversi per lo stesso utente
//
//  Non usa ViewModel: la logica è puramente computazionale e sincrona,
//  quindi può stare direttamente nella View senza bisogno di un livello intermedio.

import SwiftUI

// MARK: - ABTestingDemoView

struct ABTestingDemoView: View {

    // MARK: - Stato locale

    /// UserID inserito dall'utente per simulare il bucketing
    @State private var userID: String = "user-\(Int.random(in: 1000...9999))"

    /// Percentuale di rollout da simulare (da 0 a 100)
    @State private var rolloutPercentage: Double = 50.0

    /// Flag selezionato per la simulazione
    @State private var selectedFlag: FeatureFlagKey = .et_checkoutButtonColor

    /// Dimensione del campione per la simulazione della distribuzione
    @State private var sampleSize: Double = 500

    /// Mostra il dettaglio del calcolo SHA-256
    @State private var showCalculationDetail: Bool = false

    // MARK: - Valori calcolati

    private var bucketValue: Double {
        UserBucketing.bucketValue(userID: userID, flagKey: selectedFlag)
    }

    private var isInTreatment: Bool {
        UserBucketing.isInTreatmentGroup(
            userID: userID,
            flagKey: selectedFlag,
            rolloutPercentage: rolloutPercentage
        )
    }

    private var simulatedRate: Double {
        UserBucketing.simulatedTreatmentRate(
            flagKey: selectedFlag,
            rolloutPercentage: rolloutPercentage,
            sampleSize: Int(sampleSize)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Sezione input utente
                    UserInputSection(userID: $userID)

                    // Sezione selezione flag
                    FlagSelectorSection(selectedFlag: $selectedFlag)

                    // Sezione risultato bucketing per questo utente
                    BucketResultSection(
                        userID: userID,
                        flagKey: selectedFlag,
                        bucketValue: bucketValue,
                        rolloutPercentage: rolloutPercentage,
                        isInTreatment: isInTreatment,
                        showDetail: $showCalculationDetail
                    )

                    // Sezione controllo percentuale di rollout
                    RolloutControlSection(rolloutPercentage: $rolloutPercentage)

                    // Sezione distribuzione empirica simulata
                    SimulationSection(
                        sampleSize: $sampleSize,
                        simulatedRate: simulatedRate,
                        targetRate: rolloutPercentage,
                        flagKey: selectedFlag
                    )

                    // Sezione indipendenza tra esperimenti
                    ExperimentIndependenceSection(userID: userID)
                }
                .padding()
            }
            .navigationTitle("A/B Testing")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Sezione input userID

private struct UserInputSection: View {
    @Binding var userID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("UserID da simulare", systemImage: "person.fill")
                .font(.headline)

            HStack {
                TextField("Inserisci un UserID", text: $userID)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    userID = "user-\(Int.random(in: 1000...9999))"
                } label: {
                    Image(systemName: "dice")
                }
                .buttonStyle(.bordered)
            }

            Text("Cambia l'ID per vedere come utenti diversi vengono assegnati a varianti diverse in modo deterministico.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sezione selezione flag esperimento

private struct FlagSelectorSection: View {
    @Binding var selectedFlag: FeatureFlagKey

    // Mostra solo gli experiment toggle (et_)
    private let experimentFlags = FeatureFlagKey.allCases.filter {
        $0.category == .experiment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Esperimento", systemImage: "flask.fill")
                .font(.headline)

            Picker("Experiment Toggle", selection: $selectedFlag) {
                ForEach(experimentFlags, id: \.self) { key in
                    Text(key.displayName).tag(key)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sezione risultato bucketing

private struct BucketResultSection: View {
    let userID: String
    let flagKey: FeatureFlagKey
    let bucketValue: Double
    let rolloutPercentage: Double
    let isInTreatment: Bool
    @Binding var showDetail: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Risultato principale: variante assegnata
            VStack(spacing: 8) {
                Image(systemName: isInTreatment ? "b.circle.fill" : "a.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(isInTreatment ? .purple : .blue)
                    .animation(.spring(duration: 0.4), value: isInTreatment)

                Text(isInTreatment ? "Gruppo Trattamento" : "Gruppo Controllo")
                    .font(.title2.bold())
                    .foregroundStyle(isInTreatment ? .purple : .blue)

                Text(isInTreatment
                     ? "Questo utente vede la variante attiva (B)"
                     : "Questo utente vede la variante di controllo (A)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Dettaglio del calcolo
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation { showDetail.toggle() }
                } label: {
                    Label(
                        showDetail ? "Nascondi calcolo" : "Mostra calcolo SHA-256",
                        systemImage: "function"
                    )
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if showDetail {
                    VStack(alignment: .leading, spacing: 4) {
                        // Mostra i passaggi del calcolo
                        DetailRow(label: "Input hash",
                                  value: "\(userID):\(flagKey.rawValue)")
                        DetailRow(label: "Bucket value (normalizzato)",
                                  value: String(format: "%.6f", bucketValue))
                        DetailRow(label: "Soglia rollout",
                                  value: String(format: "%.4f (%.0f%%)", rolloutPercentage / 100.0, rolloutPercentage))
                        DetailRow(label: "bucket < soglia?",
                                  value: "\(bucketValue) < \(rolloutPercentage / 100.0) → \(isInTreatment ? "true (trattamento)" : "false (controllo)")")
                    }
                    .font(.caption)
                    .monospaced()
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Riga di dettaglio calcolo

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("→ \(label):")
                .foregroundStyle(.secondary)
            Text("   \(value)")
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Sezione controllo percentuale rollout

private struct RolloutControlSection: View {
    @Binding var rolloutPercentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Percentuale di Rollout", systemImage: "percent")
                .font(.headline)

            HStack {
                Text("0%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $rolloutPercentage, in: 0...100, step: 5)
                Text("100%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Rollout corrente:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(rolloutPercentage))%")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }

            // Barra visuale della distribuzione
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.purple)
                        .frame(width: geo.size.width * rolloutPercentage / 100)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                Circle().fill(.blue.opacity(0.2)).frame(width: 10)
                Text("Controllo (\(100 - Int(rolloutPercentage))%)")
                    .font(.caption)
                Circle().fill(.purple).frame(width: 10)
                Text("Trattamento (\(Int(rolloutPercentage))%)")
                    .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sezione simulazione distribuzione

private struct SimulationSection: View {
    @Binding var sampleSize: Double
    let simulatedRate: Double
    let targetRate: Double
    let flagKey: FeatureFlagKey

    var deviation: Double { abs(simulatedRate - targetRate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Distribuzione Simulata", systemImage: "chart.bar.fill")
                .font(.headline)

            Text("Verifica empirica: su \(Int(sampleSize)) utenti simulati, quanti finiscono nel gruppo trattamento?")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Campione:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $sampleSize, in: 100...2000, step: 100)
                Text("\(Int(sampleSize))")
                    .font(.caption.bold())
            }

            // Risultato della simulazione
            HStack(spacing: 16) {
                VStack {
                    Text(String(format: "%.1f%%", simulatedRate))
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                    Text("Tasso effettivo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(String(format: "%.1f%%", targetRate))
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                    Text("Tasso target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(String(format: "±%.1f%%", deviation))
                        .font(.title2.bold())
                        .foregroundStyle(deviation < 3 ? .green : .orange)
                    Text("Deviazione")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            if deviation < 3 {
                Label("Distribuzione uniforme — l'algoritmo funziona correttamente", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sezione indipendenza tra esperimenti

private struct ExperimentIndependenceSection: View {
    let userID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Indipendenza tra Esperimenti", systemImage: "arrow.triangle.branch")
                .font(.headline)

            Text("Lo stesso utente ha bucket diversi per ogni esperimento, garantendo l'indipendenza statistica tra test diversi.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Mostra il bucket value per ogni experiment toggle
            ForEach(FeatureFlagKey.allCases.filter { $0.category == .experiment }, id: \.self) { key in
                let bucket = UserBucketing.bucketValue(userID: userID, flagKey: key)
                HStack {
                    Text(key.displayName)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "bucket: %.4f", bucket))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
