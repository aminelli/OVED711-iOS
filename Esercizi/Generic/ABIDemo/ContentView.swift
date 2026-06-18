//
//  ContentView.swift
//  AppDemo
//
//  Created by Antonio Minelli on 05/06/2026.
//
//  Vista principale della demo ABI Stability.
//  Struttura: NavigationSplitView con lista sezioni (sidebar) e
//  pannello dettaglio con la demo interattiva specifica per la sezione.
//

import SwiftUI

// MARK: - ContentView

/// Schermata radice dell'applicazione.
///
/// Usa `@State` per creare il ViewModel direttamente nella vista radice:
/// è il pattern consigliato con `@Observable` in Swift 6 / iOS 17+
/// perché evita la dipendenza da `@StateObject` di Combine.
struct ContentView: View {

    @State private var viewModel = ABIStabilityViewModel()

    var body: some View {
        NavigationSplitView {
            // Colonna sidebar: lista delle sezioni didattiche
            SectionListView(viewModel: viewModel)
                .navigationTitle("ABI Stability")
        } detail: {
            // Colonna dettaglio: cambia in base alla sezione selezionata
            SectionDetailView(viewModel: viewModel)
        }
    }
}

// MARK: - Sidebar: lista sezioni

/// Lista delle sezioni didattiche nella sidebar.
private struct SectionListView: View {

    // @Bindable non è più necessario: la mutazione avviene via Button,
    // non tramite binding diretto su List. Usiamo il tipo osservabile direttamente.
    var viewModel: ABIStabilityViewModel

    var body: some View {
        // In iOS 26 le API List(selection:) sono state rimosse.
        // Il pattern corretto è usare List semplice con Button per aggiornare
        // la selezione nel ViewModel, e listRowBackground per evidenziare la riga attiva.
        List {
            ForEach(DemoSection.allCases) { section in
                Button {
                    viewModel.selectedSection = section
                } label: {
                    Label(section.rawValue, systemImage: section.iconName)
                        .foregroundStyle(section.tintColor)
                }
                // Sfondo tinted sulla riga della sezione selezionata
                .listRowBackground(
                    viewModel.selectedSection == section
                        ? section.tintColor.opacity(0.15)
                        : Color.clear
                )
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Dettaglio: dispatcher

/// Vista di dettaglio che seleziona il pannello corretto.
private struct SectionDetailView: View {

    let viewModel: ABIStabilityViewModel

    var body: some View {
        // Usa un Group per evitare ViewBuilder con troppi branch
        Group {
            switch viewModel.selectedSection {
            case .intro:        IntroSection(viewModel: viewModel)
            case .frozenEnum:   FrozenEnumSection(viewModel: viewModel)
            case .frozenStruct: FrozenStructSection(viewModel: viewModel)
            case .inlinable:    InlinableSection(viewModel: viewModel)
            case .resilient:    ResilientSection(viewModel: viewModel)
            }
        }
        // Animazione fluida al cambio sezione
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedSection)
        .navigationTitle(viewModel.selectedSection.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Sezione Introduzione

private struct IntroSection: View {

    let viewModel: ABIStabilityViewModel

    var body: some View {
        ScrollView {
            ExplanationCard(
                icon: "info.circle.fill",
                color: .blue,
                text: viewModel.sectionExplanation
            )
            .padding()

            // Timeline visiva: prima e dopo ABI Stability
            TimelineView()
                .padding(.horizontal)
        }
    }
}

/// Vista timeline: mostra il cambiamento introdotto dalla ABI Stability.
private struct TimelineView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cronologia")
                .font(.headline)

            TimelineRow(
                version: "Swift 4.x",
                icon: "archivebox.fill",
                color: .red,
                description: "Ogni app include la Standard Library nel bundle (~7 MB)"
            )
            TimelineRow(
                version: "Swift 5.0+\n(iOS 12.2+)",
                icon: "checkmark.seal.fill",
                color: .green,
                description: "Standard Library condivisa con il SO, come Obj-C runtime"
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TimelineRow: View {

    let version: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(version)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Sezione @frozen enum

private struct FrozenEnumSection: View {

    @Bindable var viewModel: ABIStabilityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "lock.fill",
                    color: .purple,
                    text: viewModel.sectionExplanation
                )

                // Picker per selezionare la forma
                GroupBox("Seleziona una forma (@frozen Shape)") {
                    Picker("Forma", selection: $viewModel.selectedShape) {
                        ForEach(Shape.allCases, id: \.self) { shape in
                            // Switch esaustivo SENZA @unknown default:
                            // possibile perché Shape è @frozen.
                            Label(shape.rawValue, systemImage: shape.symbolName)
                                .tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Risultato: symbol + perimetro
                GroupBox("Risultato") {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.selectedShape.symbolName)
                            .font(.system(size: 64))
                            .foregroundStyle(.purple)
                            .animation(.spring(duration: 0.3), value: viewModel.selectedShape)

                        Slider(value: $viewModel.shapeSize, in: 1...100, step: 0.5) {
                            Text("Dimensione")
                        } minimumValueLabel: {
                            Text("1")
                        } maximumValueLabel: {
                            Text("100")
                        }

                        CodeLabel(text: viewModel.perimeterText)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Sezione @frozen struct

private struct FrozenStructSection: View {

    @Bindable var viewModel: ABIStabilityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "square.3.layers.3d.down.left.fill",
                    color: .orange,
                    text: viewModel.sectionExplanation
                )

                GroupBox("Punto P1 (StablePoint @frozen)") {
                    VStack(spacing: 8) {
                        // Slider per X e Y del primo punto
                        CoordinateSlider(label: "X", value: $viewModel.pointX)
                        CoordinateSlider(label: "Y", value: $viewModel.pointY)
                        CodeLabel(text: viewModel.distanceText)
                    }
                }

                GroupBox("Somma vettoriale P1 + P2") {
                    VStack(spacing: 8) {
                        CoordinateSlider(label: "P2.X", value: $viewModel.secondPointX)
                        CoordinateSlider(label: "P2.Y", value: $viewModel.secondPointY)
                        CodeLabel(text: viewModel.sumPointText)
                    }
                }
            }
            .padding()
        }
    }
}

/// Slider etichettato per una coordinata.
///
/// Estratto come componente separato per rispettare il principio
/// di singola responsabilità e mantenere le viste più leggibili.
private struct CoordinateSlider: View {

    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 40, alignment: .leading)
                .font(.caption.monospaced())
            Slider(value: $value, in: -10...10, step: 0.1)
            Text(String(format: "%.1f", value))
                .frame(width: 36, alignment: .trailing)
                .font(.caption.monospaced())
        }
    }
}

// MARK: - Sezione @inlinable

private struct InlinableSection: View {

    let viewModel: ABIStabilityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "arrow.down.doc.fill",
                    color: .green,
                    text: viewModel.sectionExplanation
                )

                // Mostra il codice sorgente come esempio
                GroupBox("Esempio: codice dalla libreria") {
                    VStack(alignment: .leading, spacing: 8) {
                        CodeBlock(code: """
                        // Simbolo interno visibile a @inlinable
                        @usableFromInline
                        internal func approximatePerimeter(
                            shape: Shape, size: Double
                        ) -> Double { ... }

                        // Corpo copiato nel modulo chiamante
                        @inlinable
                        public func perimeterDescription(
                            for shape: Shape, size: Double
                        ) -> String {
                            let value = approximatePerimeter(
                                shape: shape, size: size
                            )
                            return String(format: "...", value)
                        }
                        """)
                    }
                }

                GroupBox("Demo a runtime") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Shape.allCases, id: \.self) { shape in
                            CodeLabel(text: perimeterDescription(for: shape, size: 5.0))
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Sezione tipo resiliente

private struct ResilientSection: View {

    let viewModel: ABIStabilityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExplanationCard(
                    icon: "arrow.triangle.2.circlepath",
                    color: .gray,
                    text: viewModel.sectionExplanation
                )

                GroupBox("Confronto: @frozen vs resiliente") {
                    ComparisonTable()
                }

                // Esempio di switch su tipo resiliente:
                // richiede @unknown default per forward-compatibility
                GroupBox("Switch su ResilientShape (richiede @unknown default)") {
                    CodeBlock(code: """
                    switch resilientShape {
                    case .circle:   ...
                    case .square:   ...
                    case .triangle: ...
                    @unknown default:
                        // Gestisce casi aggiunti in versioni future
                        // senza rompere l'ABI dei client esistenti
                        break
                    }
                    """)
                }
            }
            .padding()
        }
    }
}

/// Tabella comparativa @frozen vs resiliente.
private struct ComparisonTable: View {

    private let rows: [(feature: String, frozen: String, resilient: String)] = [
        ("Nuovi casi futuri",    "No (ABI-breaking)",  "Sì"),
        ("Switch esaustivo",     "Sì",                 "No (@unknown default)"),
        ("Ottimizzazione size",  "Sì",                 "No"),
        ("Overhead runtime",     "Nessuno",            "Piccolo"),
        ("Default per public",   "No",                 "Sì"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Intestazione
            HStack {
                Text("Caratteristica").frame(maxWidth: .infinity, alignment: .leading)
                Text("@frozen").frame(width: 100).foregroundStyle(.purple)
                Text("Resiliente").frame(width: 100).foregroundStyle(.gray)
            }
            .font(.caption.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(.quaternary)

            Divider()

            // Righe dati
            ForEach(rows, id: \.feature) { row in
                HStack {
                    Text(row.feature)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.frozen)
                        .font(.caption)
                        .frame(width: 100)
                        .foregroundStyle(.purple)
                    Text(row.resilient)
                        .font(.caption)
                        .frame(width: 100)
                        .foregroundStyle(.gray)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
    }
}

// MARK: - Componenti UI riutilizzabili

/// Card con icona colorata e testo esplicativo in Markdown.
private struct ExplanationCard: View {

    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            // Text in SwiftUI supporta un sottoinsieme di Markdown
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Etichetta monospaziata per output di codice a riga singola.
private struct CodeLabel: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.primary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Blocco di codice multiriga con sfondo distinto.
private struct CodeBlock: View {

    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .padding(12)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

// Binding necessari per la preview: `@Bindable` richiede un oggetto concreto.
#Preview {
    ContentView()
}
