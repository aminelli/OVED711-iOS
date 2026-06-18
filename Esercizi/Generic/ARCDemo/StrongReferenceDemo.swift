//
//  StrongReferenceDemo.swift
//  ARCDemo
//
//  Scenario 1: riferimenti `strong` e retain cycle.
//  ARC aumenta il reference count ogni volta che un riferimento forte punta a un oggetto.
//  Quando due oggetti si referenziano a vicenda tramite `strong`, nessuno dei due
//  raggiungerà mai un reference count di 0: questo è un retain cycle e causa memory leak.
//

import SwiftUI

// MARK: - Modello

/// Rappresenta un ufficio che può avere un manager assegnato.
/// Il campo `manager` è un riferimento forte: contribuisce al reference count di `Manager`.
final class Office {

    /// Nome dell'ufficio.
    let name: String

    /// Riferimento forte al manager: se `Manager` tiene a sua volta un riferimento forte
    /// a questo ufficio si crea un retain cycle.
    var manager: Manager?

    init(name: String) {
        self.name = name
        // Stampa a console per verificare che l'oggetto venga creato
        print("✅ Office '\(name)' allocato")
    }

    deinit {
        // Se questo messaggio NON compare, l'oggetto non è stato deallocato (memory leak)
        print("♻️ Office '\(name)' deallocato")
    }
}

/// Rappresenta un manager assegnato a un ufficio.
final class Manager {

    /// Nome del manager.
    let name: String

    /// Riferimento forte all'ufficio: combinato con `Office.manager`, forma un retain cycle.
    var office: Office?

    init(name: String) {
        self.name = name
        print("✅ Manager '\(name)' allocato")
    }

    deinit {
        // Se questo messaggio NON compare dopo aver azzerato le variabili locali,
        // ARC non ha potuto liberare l'oggetto a causa del ciclo forte.
        print("♻️ Manager '\(name)' deallocato")
    }
}

// MARK: - ViewModel

/// ViewModel che gestisce la simulazione del retain cycle.
/// Usiamo `@Observable` (Swift 5.9+/6.x) al posto di `ObservableObject` per
/// sfruttare il nuovo sistema di tracking delle dipendenze senza `@Published`.
@Observable
final class StrongReferenceViewModel {

    /// Log degli eventi ARC mostrato nella UI.
    var log: [String] = []

    /// Crea due oggetti con riferimenti forti reciproci, poi li "rilascia".
    /// Poiché il cycle rimane, `deinit` non verrà mai chiamato.
    func createRetainCycle() {
        log.removeAll()
        appendLog("--- Creazione oggetti con retain cycle ---")

        // ARC: reference count di `office` = 1 (variabile locale `office`)
        let office = Office(name: "HQ")
        appendLog("Office creato (RC = 1)")

        // ARC: reference count di `manager` = 1 (variabile locale `manager`)
        let manager = Manager(name: "Alice")
        appendLog("Manager creato (RC = 1)")

        // office.manager → forte → RC di `manager` sale a 2
        office.manager = manager
        appendLog("office.manager = manager → RC manager = 2")

        // manager.office → forte → RC di `office` sale a 2
        manager.office = office
        appendLog("manager.office = office → RC office = 2")

        appendLog("--- Fine scope: variabili locali rilasciate ---")
        // Uscendo dallo scope, le variabili locali vengono distrutte:
        //   RC di `office`  scende da 2 a 1 (rimane il riferimento da manager.office)
        //   RC di `manager` scende da 2 a 1 (rimane il riferimento da office.manager)
        // Nessuno dei due oggetti raggiunge RC = 0 → nessun deinit → MEMORY LEAK
        appendLog("⚠️ deinit NON chiamato: retain cycle attivo!")
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        log.append(message)
        print(message)
    }
}

// MARK: - View

/// Vista che illustra il retain cycle da riferimenti `strong` reciproci.
struct StrongReferenceDemo: View {

    @State private var viewModel = StrongReferenceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Spiegazione concettuale
                GroupBox("Concetto") {
                    Text("""
                    Un riferimento **strong** (predefinito in Swift) aumenta il \
                    reference count dell'oggetto puntato. \
                    Se due oggetti si referenziano a vicenda con `strong`, \
                    ARC non può mai portare il loro contatore a 0: \
                    si crea un **retain cycle** e gli oggetti rimangono in memoria \
                    per tutta la vita dell'app.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }

                // Pulsante di simulazione
                Button("Crea Retain Cycle") {
                    viewModel.createRetainCycle()
                }
                .buttonStyle(.borderedProminent)

                // Log ARC in tempo reale
                if !viewModel.log.isEmpty {
                    GroupBox("Log ARC") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.log, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(entry.hasPrefix("⚠️") ? .red : .primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Riepilogo
                GroupBox("Riepilogo") {
                    Text("""
                    Usa `strong` per esprimere proprietà: quando la vita dell'oggetto \
                    puntato deve essere legata all'oggetto che lo contiene. \
                    Evita riferimenti forti bidirezionali tra oggetti con ciclo di vita \
                    simmetrico: usa invece `weak` o `unowned` su uno dei due lati.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Strong Reference")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StrongReferenceDemo()
    }
}
