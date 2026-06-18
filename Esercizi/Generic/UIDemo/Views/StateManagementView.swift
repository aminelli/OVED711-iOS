//
//  StateManagementView.swift
//  UIDemo
//
//  Showcase completo dello state management in SwiftUI moderno (iOS 17+):
//
//  1. @State          - Stato locale di una singola view
//  2. @Binding        - Condivisione dello stato tra parent e child
//  3. @Observable     - Stato condiviso tra view distanti (iOS 17+)
//  4. @Environment    - Iniezione di dipendenze tramite l'albero di view
//  5. @StateObject    - Oggetto osservabile legato al ciclo di vita della view
//
//  Nota Swift 6: @Observable è @MainActor-isolated quando usato con SwiftUI.
//  Non è necessario annotare manualmente le view con @MainActor.
//

import SwiftUI
import Observation

// MARK: - StateManagementView

struct StateManagementView: View {

    // MARK: - @Environment per accesso allo stato globale
    /// Accede all'AppState iniettato in WindowGroup.
    /// Il tipo Bindable di iOS 17 permette di creare binding da @Observable.
    @Environment(AppState.self) private var appState

    // MARK: - @State locale
    /// Stato locale: il tab selezionato nel segmented control
    @State private var selectedTab: StateDemo = .localState
    /// Testo inserito nel campo di testo
    @State private var inputText: String = ""
    /// Flag per mostrare la sezione avanzata
    @State private var showAdvanced: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {

                // Picker per scegliere la demo da visualizzare
                Picker("Demo", selection: $selectedTab) {
                    ForEach(StateDemo.allCases) { demo in
                        Text(demo.title).tag(demo)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.md)

                // Contenuto della demo selezionata
                Group {
                    switch selectedTab {
                    case .localState:
                        localStateDemo
                    case .binding:
                        bindingDemo
                    case .observable:
                        observableDemo
                    case .environment:
                        environmentDemo
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .animation(AppTheme.Animation.standard, value: selectedTab)
            }
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .navigationTitle("State Management")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Demo 1: @State locale

    private var localStateDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            demoHeader(
                title: "@State",
                subtitle: "Stato privato, locale alla view. Re-render solo quando cambia.",
                color: .blue
            )

            LocalStateCounter()

            Divider()

            // Demo TextField con @State
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("TextField con @State")
                    .font(AppTheme.Typography.headline)

                TextField("Scrivi qualcosa...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                if !inputText.isEmpty {
                    Text("Caratteri: \(inputText.count) | Parole: \(inputText.split(separator: " ").count)")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .transition(.opacity)
                }
            }

            // Demo toggle e slider
            LocalControlsDemo()
        }
        .cardStyle()
    }

    // MARK: - Demo 2: @Binding

    private var bindingDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            demoHeader(
                title: "@Binding",
                subtitle: "Condivide lo stato tra parent e child senza duplicarlo.",
                color: .purple
            )

            BindingParentDemo()
        }
        .cardStyle()
    }

    // MARK: - Demo 3: @Observable

    private var observableDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            demoHeader(
                title: "@Observable",
                subtitle: "Stato condiviso tra view distanti. iOS 17+ sostituto di ObservableObject.",
                color: .orange
            )

            ObservableDemo()
        }
        .cardStyle()
    }

    // MARK: - Demo 4: @Environment

    private var environmentDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            demoHeader(
                title: "@Environment",
                subtitle: "Iniezione di dipendenze tramite l'albero di view SwiftUI.",
                color: .green
            )

            // Mostra i valori dell'AppState globale (iniettato via environment)
            VStack(spacing: AppTheme.Spacing.sm) {
                environmentRow(
                    label: "Tab selezionato",
                    value: appState.selectedTab.title,
                    icon: "tab"
                )
                environmentRow(
                    label: "Contatore globale",
                    value: "\(appState.globalCounter)",
                    icon: "number"
                )
                environmentRow(
                    label: "Glass effects",
                    value: appState.glassEffectsEnabled ? "Abilitati" : "Disabilitati",
                    icon: "drop.fill"
                )
                environmentRow(
                    label: "Utente",
                    value: appState.userProfile.name,
                    icon: "person.circle.fill"
                )
            }

            Divider()

            // Modifica l'AppState dall'environment
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Modifica lo stato globale")
                    .font(AppTheme.Typography.headline)

                // Usa @Bindable per creare binding da @Observable (iOS 17+)
                let bindableState = Bindable(appState)

                Toggle("LiquidGlass Effects", isOn: bindableState.glassEffectsEnabled)
                Toggle("Animazioni", isOn: bindableState.animationsEnabled)
            }

            Button("Incrementa contatore globale (+1)") {
                appState.incrementCounter()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    // MARK: - Helpers UI

    private func demoHeader(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private func environmentRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .bold()
        }
    }
}

// MARK: - StateDemo Enum

private enum StateDemo: String, CaseIterable, Identifiable {
    case localState, binding, observable, environment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localState:  return "@State"
        case .binding:     return "@Binding"
        case .observable:  return "@Observable"
        case .environment: return "@Environment"
        }
    }
}

// MARK: - Sottocomponenti

// MARK: LocalStateCounter

/// Dimostra @State con un contatore locale isolato nella view.
/// Ogni istanza ha il proprio stato indipendente.
private struct LocalStateCounter: View {
    // @State crea uno storage privato legato al ciclo di vita della view
    @State private var count: Int = 0
    @State private var showConfetti: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Contatore locale")
                    .font(AppTheme.Typography.headline)
                Spacer()
                // contentTransition anima la transizione numerica
                Text("\(count)")
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(count > 0 ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(AppTheme.Animation.fast, value: count)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    withAnimation(AppTheme.Animation.fast) { count -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(count > 0 ? AppTheme.Colors.error : AppTheme.Colors.separator)
                }
                .disabled(count <= 0)

                Slider(value: .init(
                    get: { Double(count) },
                    set: { count = Int($0) }
                ), in: 0...100, step: 1)

                Button {
                    withAnimation(AppTheme.Animation.bouncy) {
                        count += 1
                        if count % 10 == 0 { showConfetti = true }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            if showConfetti {
                Text("🎉 Multiplo di 10!")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation(AppTheme.Animation.fast) { showConfetti = false }
                        }
                    }
            }
        }
    }
}

// MARK: LocalControlsDemo

private struct LocalControlsDemo: View {
    @State private var isOn: Bool = false
    @State private var sliderValue: Double = 0.5
    @State private var selectedFruit: String = "Mela"
    private let fruits = ["Mela", "Banana", "Arancia", "Kiwi"]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Toggle("Toggle @State", isOn: $isOn)
            Slider(value: $sliderValue, in: 0...1) {
                Text("Slider")
            } minimumValueLabel: {
                Image(systemName: "speaker")
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3")
            }

            Picker("Frutto preferito", selection: $selectedFruit) {
                ForEach(fruits, id: \.self) { Text($0) }
            }
            .pickerStyle(.menu)

            Text("Toggle: \(isOn ? "ON" : "OFF") | Slider: \(sliderValue, specifier: "%.2f") | Frutto: \(selectedFruit)")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: BindingParentDemo

/// Dimostra come un parent passa un @Binding al child,
/// permettendo al child di modificare lo stato del parent.
private struct BindingParentDemo: View {
    // Lo stato "vive" qui nel parent
    @State private var colorIndex: Int = 0
    @State private var intensity: Double = 0.6

    private let colors: [Color] = [.blue, .purple, .orange, .green, .red, .teal]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Parent gestisce lo stato")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // Rettangolo preview che reagisce ai binding del child
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(colors[colorIndex].opacity(intensity))
                .frame(height: 80)
                .overlay(
                    Text("Colore \(colorIndex + 1) | Intensità: \(intensity, specifier: "%.0f")%")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.white)
                )
                .animation(AppTheme.Animation.standard, value: colorIndex)
                .animation(AppTheme.Animation.fast, value: intensity)

            // Child riceve binding: può leggere E modificare lo stato del parent
            BindingChildControls(
                colorIndex: $colorIndex,
                intensity: $intensity,
                colorCount: colors.count
            )
        }
    }
}

/// View figlia che riceve @Binding e può modificare lo stato del parent.
private struct BindingChildControls: View {
    // $colorIndex e $intensity sono binding: modificarli aggiorna il parent
    @Binding var colorIndex: Int
    @Binding var intensity: Double
    let colorCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Child modifica tramite @Binding")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            HStack {
                ForEach(0..<colorCount, id: \.self) { i in
                    Button {
                        withAnimation(AppTheme.Animation.standard) { colorIndex = i }
                    } label: {
                        Circle()
                            .fill([Color.blue, .purple, .orange, .green, .red, .teal][i])
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: colorIndex == i ? 3 : 0)
                            )
                            .scaleEffect(colorIndex == i ? 1.2 : 1.0)
                            .animation(AppTheme.Animation.fast, value: colorIndex)
                    }
                }
                Spacer()
            }

            Slider(value: $intensity, in: 0.1...1.0) {
                Text("Intensità")
            }
        }
    }
}

// MARK: ObservableDemo

/// Modello @Observable condiviso tra più view.
/// Senza @Observable (o ObservableObject), queste view non si aggiornerebbero
/// quando il modello cambia.
@Observable
@MainActor
private final class SharedCounter {
    var value: Int = 0
    var history: [Int] = []

    func increment() {
        value += 1
        history.append(value)
        if history.count > 10 { history.removeFirst() }
    }

    func reset() {
        value = 0
        history.removeAll()
    }
}

private struct ObservableDemo: View {
    // @State con oggetto @Observable: il ciclo di vita è legato alla view
    @State private var counter = SharedCounter()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Contatore @Observable condiviso")
                .font(AppTheme.Typography.headline)

            // Più view che leggono lo stesso oggetto Observable
            HStack(spacing: AppTheme.Spacing.md) {
                ObservableReaderA(counter: counter)
                ObservableReaderB(counter: counter)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Button("Incrementa") {
                    withAnimation(AppTheme.Animation.fast) {
                        counter.increment()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Reset") {
                    withAnimation(AppTheme.Animation.fast) {
                        counter.reset()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            // Cronologia degli ultimi 10 incrementi
            if !counter.history.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        ForEach(Array(counter.history.enumerated()), id: \.offset) { _, val in
                            Text("\(val)")
                                .font(AppTheme.Typography.caption)
                                .padding(.horizontal, AppTheme.Spacing.xs)
                                .padding(.vertical, 4)
                                .background(AppTheme.Colors.primary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

/// View A: legge il valore corrente del counter @Observable
private struct ObservableReaderA: View {
    let counter: SharedCounter

    var body: some View {
        VStack {
            Text("Reader A")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("\(counter.value)")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}

/// View B: mostra la stessa informazione ma con stile diverso
private struct ObservableReaderB: View {
    let counter: SharedCounter

    var body: some View {
        VStack {
            Text("Reader B")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            // Mostra la parità
            Image(systemName: counter.value % 2 == 0 ? "circle.fill" : "diamond.fill")
                .font(.largeTitle)
                .foregroundStyle(counter.value % 2 == 0 ? Color.purple : Color.orange)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }
}

#Preview {
    NavigationStack {
        StateManagementView()
    }
    .environment(AppState())
}
