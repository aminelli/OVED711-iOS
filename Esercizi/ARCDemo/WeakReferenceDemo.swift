//
//  WeakReferenceDemo.swift
//  ARCDemo
//
//  Scenario 2: riferimenti `weak` per rompere il retain cycle.
//  Un riferimento `weak` NON incrementa il reference count dell'oggetto puntato.
//  Per questo motivo, Swift richiede che sia sempre di tipo opzionale: quando
//  l'oggetto viene deallocato, il riferimento viene azzerato automaticamente a `nil`.
//

import SwiftUI

// MARK: - Modello

/// Rappresenta un documento all'interno di un progetto.
final class Document {

    /// Titolo del documento.
    let title: String

    /// Riferimento forte al progetto proprietario.
    /// Il documento appartiene al progetto: ha senso che ne estenda il ciclo di vita.
    var project: Project?

    init(title: String) {
        self.title = title
        print("✅ Document '\(title)' allocato")
    }

    deinit {
        print("♻️ Document '\(title)' deallocato")
    }
}

/// Rappresenta un progetto che contiene documenti.
final class Project {

    /// Nome del progetto.
    let name: String

    /// Riferimento DEBOLE al documento corrente.
    /// Usando `weak`, il documento può essere deallocato indipendentemente dal progetto:
    /// il suo reference count non viene incrementato da questo riferimento.
    /// Swift impone che sia `Optional` perché potrebbe diventare `nil` in qualsiasi momento.
    weak var currentDocument: Document?

    init(name: String) {
        self.name = name
        print("✅ Project '\(name)' allocato")
    }

    deinit {
        print("♻️ Project '\(name)' deallocato")
    }
}

// MARK: - ViewModel

/// ViewModel che dimostra la risoluzione del retain cycle tramite `weak`.
@Observable
final class WeakReferenceViewModel {

    /// Log degli eventi ARC.
    var log: [String] = []

    /// Crea un progetto e un documento collegati, poi rilascia il documento.
    /// Grazie a `weak`, il documento viene deallocato e `currentDocument` diventa `nil`.
    func demonstrateWeakReference() {
        log.removeAll()
        appendLog("--- Creazione oggetti con riferimento weak ---")

        // RC di `project` = 1 (variabile locale)
        let project = Project(name: "MyApp")

        // Creiamo il documento in uno scope annidato per controllarne il ciclo di vita
        do {
            // RC di `document` = 1 (variabile locale nello scope interno)
            let document = Document(title: "README")
            appendLog("Document creato (RC = 1)")

            // `project.currentDocument` è weak → RC di `document` rimane 1
            project.currentDocument = document
            appendLog("project.currentDocument = document (weak, RC rimane 1)")

            // Il documento punta al progetto con strong → RC di `project` sale a 2
            document.project = project
            appendLog("document.project = project (strong, RC project = 2)")

            appendLog("--- Fine scope interno: variabile locale `document` rilasciata ---")
            // Uscendo da questo scope, RC di `document` scende da 1 a 0:
            // il riferimento `weak` non conta! → deinit viene chiamato immediatamente.
        }

        appendLog("✅ document.deinit chiamato: nessun retain cycle!")
        // Dopo il deinit, `project.currentDocument` viene azzerato automaticamente a nil
        appendLog("project.currentDocument è nil: \(project.currentDocument == nil)")
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        log.append(message)
        print(message)
    }
}

// MARK: - View

/// Vista che illustra come `weak` rompe il retain cycle.
struct WeakReferenceDemo: View {

    @State private var viewModel = WeakReferenceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox("Concetto") {
                    Text("""
                    Un riferimento **weak** non incrementa il reference count. \
                    Swift lo rende sempre `Optional`: quando l'oggetto puntato \
                    viene deallocato, il riferimento diventa automaticamente `nil`. \
                    Usalo sul lato "figlio" di una relazione padre–figlio per \
                    evitare retain cycle, oppure per i delegate pattern.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }

                Button("Dimostra weak Reference") {
                    viewModel.demonstrateWeakReference()
                }
                .buttonStyle(.borderedProminent)

                if !viewModel.log.isEmpty {
                    GroupBox("Log ARC") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.log, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(entry.hasPrefix("✅") ? .green : .primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Weak vs Strong — quando scegliere") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Strong: il riferimento deve prolungare la vita dell'oggetto (es. proprietà padre → figlio).", systemImage: "link")
                        Label("Weak: il riferimento NON deve prolungare la vita (es. delegate, riferimento inverso figlio → padre).", systemImage: "link.badge.minus")
                    }
                    .font(.footnote)
                }

                GroupBox("Riepilogo") {
                    Text("""
                    Usa `weak` ogni volta che due oggetti si referenziano a vicenda \
                    e uno dei due "appartiene" all'altro. Il lato non-proprietario \
                    deve essere `weak` per evitare il retain cycle. \
                    È il pattern classico dei **delegate** in UIKit/AppKit.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Weak Reference")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WeakReferenceDemo()
    }
}
