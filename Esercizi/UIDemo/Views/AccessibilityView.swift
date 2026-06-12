//
//  AccessibilityView.swift
//  UIDemo
//
//  Showcase completo delle best practices di accessibilità in SwiftUI:
//
//  1. accessibilityLabel / accessibilityHint / accessibilityValue
//  2. accessibilityTraits (button, header, image, link, ...)
//  3. Dynamic Type con scaleFonts
//  4. Contrasto e colori accessibili
//  5. Reduce Motion: rispetta la preferenza di sistema
//  6. VoiceOver groups e rotor
//  7. accessibilityElement(children:) per raggruppare/nascondere elementi
//  8. Livelli di titolo con .accessibilityAddTraits(.isHeader)
//
//  Riferimento: WWDC 2023 "Build accessible apps with SwiftUI and UIKit"
//

import SwiftUI

// MARK: - AccessibilityView

struct AccessibilityView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorContrast
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(AppState.self) private var appState

    @State private var selectedSection: A11ySection = .labels
    @State private var counter: Int = 0
    @State private var isAnimating: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {

                // Banner con stato accessibilità corrente del dispositivo
                accessibilityStatusBanner

                // Segmented control per le sezioni
                Picker("Sezione", selection: $selectedSection) {
                    ForEach(A11ySection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.md)

                // Contenuto della sezione selezionata
                Group {
                    switch selectedSection {
                    case .labels:
                        labelsDemo
                    case .dynamicType:
                        dynamicTypeDemo
                    case .motion:
                        motionDemo
                    case .contrast:
                        contrastDemo
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .animation(reduceMotion ? .none : AppTheme.Animation.standard, value: selectedSection)
            }
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Status Banner

    /// Mostra le feature di accessibilità attualmente attive sul dispositivo.
    private var accessibilityStatusBanner: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Stato accessibilità")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                // Intestazione di sezione per VoiceOver
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.xs
            ) {
                statusChip(
                    label: "VoiceOver",
                    isActive: voiceOverEnabled,
                    icon: "accessibility"
                )
                statusChip(
                    label: "Reduce Motion",
                    isActive: reduceMotion,
                    icon: "figure.walk"
                )
                statusChip(
                    label: "High Contrast",
                    isActive: colorContrast == .increased,
                    icon: "circle.lefthalf.filled"
                )
                statusChip(
                    label: "Dynamic Type XL",
                    isActive: dynamicTypeSize >= .xLarge,
                    icon: "textformat.size"
                )
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .padding(.horizontal, AppTheme.Spacing.md)
        // Raggruppa l'intero banner come un singolo elemento VoiceOver
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stato accessibilità: VoiceOver \(voiceOverEnabled ? "attivo" : "disattivo"), Reduce Motion \(reduceMotion ? "attivo" : "disattivo")")
    }

    // MARK: - Demo 1: Labels, Hints, Traits

    private var labelsDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sectionTitle("accessibilityLabel / Hint / Traits")

            // Esempio 1: immagine decorativa (nascosta a VoiceOver)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Immagine decorativa (nascosta a VoiceOver)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        // .decorative: VoiceOver ignora questa immagine
                        .accessibilityHidden(true)

                    Text("Elemento preferito")
                }
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
            }

            // Esempio 2: bottone con label e hint descrittivi
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Bottone con label e hint")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button {
                    counter += 1
                    appState.incrementCounter()
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("\(counter)")
                            .contentTransition(.numericText())
                    }
                    .padding()
                    .background(AppTheme.Colors.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                }
                // Label descrittiva per VoiceOver (sovrascrive il testo visivo)
                .accessibilityLabel("Mi piace: \(counter)")
                // Hint spiega cosa succede al tocco
                .accessibilityHint("Aumenta il contatore dei like")
                // Value aggiuntivo letto da VoiceOver
                .accessibilityValue("\(counter) like")
            }

            // Esempio 3: Progress view accessibile
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Progress View accessibile")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                let progress = Double(counter % 11) / 10.0
                ProgressView(value: progress)
                    .tint(AppTheme.Colors.primary)
                    // VoiceOver leggerà "Progresso: 70%" invece del default
                    .accessibilityLabel("Progresso caricamento")
                    .accessibilityValue("\(Int(progress * 100))%")
            }

            // Esempio 4: Raggruppa più elementi in uno
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Raggruppamento elementi VoiceOver")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                // Senza raggruppamento VoiceOver leggerebbe ogni elemento separatamente
                VStack(alignment: .leading, spacing: 4) {
                    Text("Titolo card")
                        .font(AppTheme.Typography.headline)
                    Text("Sottotitolo descrittivo")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Label("Attivo", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                        .font(AppTheme.Typography.caption)
                }
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                // .combine raggruppa tutti i figli in un unico elemento VoiceOver
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }

    // MARK: - Demo 2: Dynamic Type

    private var dynamicTypeDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sectionTitle("Dynamic Type")

            Text("Categoria corrente: \(dynamicTypeSize.description)")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // scaledFont mostra come i font scalano con Dynamic Type
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(fontSamples, id: \.name) { sample in
                    HStack {
                        Text(sample.name)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        Text("Testo di esempio")
                            .font(sample.font)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Divider()

            // Layout adattivo che cambia asse con taglia grande
            ViewThatFits {
                // Layout orizzontale per taglie normali
                HStack(spacing: AppTheme.Spacing.md) {
                    adaptiveContent
                }
                // Layout verticale per taglie molto grandi (accessibilità)
                VStack(spacing: AppTheme.Spacing.sm) {
                    adaptiveContent
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var adaptiveContent: some View {
        Label("Utente", systemImage: "person.circle.fill")
            .foregroundStyle(AppTheme.Colors.primary)
        Text("Layout adattivo con ViewThatFits")
            .font(AppTheme.Typography.body)
    }

    // MARK: - Demo 3: Reduce Motion

    private var motionDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sectionTitle("Reduce Motion")

            Text(reduceMotion
                 ? "⚠️ Reduce Motion è ATTIVO: le animazioni sono ridotte"
                 : "✅ Animazioni complete abilitate")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(reduceMotion ? AppTheme.Colors.warning : AppTheme.Colors.success)
                .padding(AppTheme.Spacing.sm)
                .background((reduceMotion ? AppTheme.Colors.warning : AppTheme.Colors.success).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

            // Cerchio animato che rispetta Reduce Motion
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Animazione che rispetta accessibilityReduceMotion")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    // Se Reduce Motion è attivo, usa un'animazione semplice (fade)
                    // invece di quella rotatoria potenzialmente nauseante
                    .rotationEffect(isAnimating && !reduceMotion ? .degrees(360) : .zero)
                    .scaleEffect(isAnimating ? (reduceMotion ? 1.1 : 1.0) : 1.0)
                    .opacity(isAnimating && reduceMotion ? 0.6 : 1.0)
                    .animation(
                        reduceMotion
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .linear(duration: 2).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .onAppear { isAnimating = true }
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    // MARK: - Demo 4: Contrasto

    private var contrastDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sectionTitle("Contrasto e colori accessibili")

            Text("Contrasto corrente: \(colorContrast == .increased ? "Alto" : "Standard")")
                .font(AppTheme.Typography.subheadline)

            // Confronto colori con e senza accessibilità
            ForEach(contrastPairs, id: \.label) { pair in
                HStack {
                    Text(pair.label)
                        .font(AppTheme.Typography.caption)
                        .frame(width: 80, alignment: .leading)
                    // Colore standard
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(colorContrast == .increased ? pair.accessible : pair.standard)
                        .frame(height: 40)
                        .overlay(
                            Text("Aa")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.white)
                        )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(pair.label): colore \(colorContrast == .increased ? "ad alto contrasto" : "standard")")
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Typography.title3)
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func statusChip(label: String, isActive: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption2)
            Spacer()
            Circle()
                .fill(isActive ? AppTheme.Colors.success : AppTheme.Colors.separator)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(isActive ? "attivo" : "disattivo")")
    }

    private var fontSamples: [(name: String, font: Font)] {[
        ("largeTitle", AppTheme.Typography.largeTitle),
        ("title",      AppTheme.Typography.title),
        ("headline",   AppTheme.Typography.headline),
        ("body",       AppTheme.Typography.body),
        ("footnote",   AppTheme.Typography.footnote),
        ("caption",    AppTheme.Typography.caption),
    ]}

    private var contrastPairs: [(label: String, standard: Color, accessible: Color)] {[
        ("Primary",   Color.blue.opacity(0.7),   Color.blue),
        ("Success",   Color.green.opacity(0.7),  Color.green),
        ("Error",     Color.red.opacity(0.7),    Color.red),
        ("Warning",   Color.orange.opacity(0.7), Color.orange),
    ]}
}

// MARK: - A11ySection Enum

private enum A11ySection: String, CaseIterable, Identifiable {
    case labels, dynamicType, motion, contrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .labels:      return "Labels"
        case .dynamicType: return "Dynamic Type"
        case .motion:      return "Motion"
        case .contrast:    return "Contrasto"
        }
    }
}

// MARK: - DynamicTypeSize description

extension DynamicTypeSize {
    var description: String {
        switch self {
        case .xSmall:      return "xSmall"
        case .small:       return "Small"
        case .medium:      return "Medium"
        case .large:       return "Large (default)"
        case .xLarge:      return "xLarge"
        case .xxLarge:     return "xxLarge"
        case .xxxLarge:    return "xxxLarge"
        case .accessibility1: return "Accessibility 1"
        case .accessibility2: return "Accessibility 2"
        case .accessibility3: return "Accessibility 3"
        case .accessibility4: return "Accessibility 4"
        case .accessibility5: return "Accessibility 5"
        @unknown default:  return "Sconosciuto"
        }
    }
}

#Preview {
    NavigationStack {
        AccessibilityView()
    }
    .environment(AppState())
}
