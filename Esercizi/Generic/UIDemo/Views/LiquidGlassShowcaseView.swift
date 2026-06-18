//
//  LiquidGlassShowcaseView.swift
//  UIDemo
//
//  Showcase del materiale LiquidGlass introdotto con iOS 26.
//  LiquidGlass è il nuovo linguaggio visivo di Apple: un materiale
//  traslucente con rifrazione dinamica della luce.
//
//  API chiave iOS 26:
//  - `.glassEffect()` - modifier per applicare il materiale glass
//  - `.glassEffect(.regular, in: Shape)` - glass con shape specificata
//  - `GlassEffectContainer` - gestisce la composizione dei layer glass
//
//  Differenza con i materiali precedenti:
//  - .ultraThinMaterial / .thinMaterial (iOS 15): blur statico
//  - LiquidGlass (iOS 26): rifrazione dinamica + integrazione con la luce
//
//  Riferimento: WWDC 2025 "Meet Liquid Glass", "Build a SwiftUI app with the new design"
//

import SwiftUI

// MARK: - LiquidGlassShowcaseView

struct LiquidGlassShowcaseView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.appTheme) private var theme

    /// Controlla la visibilità del confronto SwiftUI vs LiquidGlass
    @State private var showComparison: Bool = false
    /// Sfondo selezionato per visualizzare l'effetto glass
    @State private var selectedBackground: GlassBackground = .gradient
    /// Tint colorato opzionale applicato al glass
    @State private var tintColor: Color = .clear
    @State private var tintOpacity: Double = 0.0
    /// Forma del glass
    @State private var selectedShape: GlassShape = .roundedRect

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {

                // MARK: Hero interattivo
                glassHero

                // MARK: Controlli di personalizzazione
                glassControls

                Divider()

                // MARK: Componenti glass
                glassComponents

                Divider()

                // MARK: Confronto SwiftUI vs LiquidGlass
                comparisonSection

                Spacer(minLength: AppTheme.Spacing.xxxl)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Liquid Glass")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Interattivo

    /// Area principale dove si vede l'effetto glass su sfondo configurabile.
    private var glassHero: some View {
        ZStack {
            // Sfondo configurabile (gradient, image placeholder, colori)
            heroBackground
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xLarge))

            // GlassEffectContainer coordina i livelli glass sovrapposti.
            // Tutti i .glassEffect() all'interno condividono la stessa
            // composizione traslucente, evitando "stacking" non desiderato.
            GlassEffectContainer {
                VStack(spacing: AppTheme.Spacing.md) {
                    // Card glass principale
                    glassCard

                    // Toolbar glass in basso
                    GlassToolbar {
                        Button {
                            appState.incrementCounter()
                        } label: {
                            Label("Like", systemImage: "heart.fill")
                                .foregroundStyle(.red)
                        }

                        Divider().frame(height: 20)

                        Button {} label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider().frame(height: 20)

                        Button {} label: {
                            Label("More", systemImage: "ellipsis")
                        }
                    }
                    .foregroundStyle(.white)
                }
                .padding(AppTheme.Spacing.md)
            }
        }
    }

    /// Sfondo dell'area hero, configurabile tramite picker.
    @ViewBuilder
    private var heroBackground: some View {
        switch selectedBackground {
        case .gradient:
            LinearGradient(
                colors: [.indigo, .blue, .cyan, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .colorful:
            ZStack {
                Color.purple
                GeometryReader { geo in
                    Circle()
                        .fill(.orange.opacity(0.7))
                        .frame(width: 200, height: 200)
                        .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.1)
                    Circle()
                        .fill(.pink.opacity(0.7))
                        .frame(width: 150, height: 150)
                        .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.5)
                    Circle()
                        .fill(.cyan.opacity(0.7))
                        .frame(width: 180, height: 180)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.4)
                }
            }
        case .dark:
            LinearGradient(
                colors: [.black, Color(white: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .light:
            LinearGradient(
                colors: [Color(white: 0.9), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Card con effetto glass al centro dell'hero.
    private var glassCard: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "drop.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white)

            Text("LiquidGlass")
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.white)

            Text("iOS 26 · Design Language")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(AppTheme.Spacing.lg)
        // .glassEffect() applica il materiale LiquidGlass con la shape specificata
        .applyGlassShape(selectedShape)
    }

    // MARK: - Controlli di personalizzazione

    private var glassControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Configura il Glass")
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            // Selettore sfondo
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Sfondo")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(GlassBackground.allCases) { bg in
                        Button {
                            withAnimation(AppTheme.Animation.fast) {
                                selectedBackground = bg
                            }
                        } label: {
                            Text(bg.title)
                                .font(AppTheme.Typography.caption)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(selectedBackground == bg
                                    ? AppTheme.Colors.primary
                                    : AppTheme.Colors.secondaryBackground)
                                .foregroundStyle(selectedBackground == bg ? .white : AppTheme.Colors.textPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Selettore forma
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Forma Glass")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(GlassShape.allCases) { shape in
                        Button {
                            withAnimation(AppTheme.Animation.fast) {
                                selectedShape = shape
                            }
                        } label: {
                            Text(shape.title)
                                .font(AppTheme.Typography.caption)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(selectedShape == shape
                                    ? AppTheme.Colors.primary
                                    : AppTheme.Colors.secondaryBackground)
                                .foregroundStyle(selectedShape == shape ? .white : AppTheme.Colors.textPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Componenti Glass

    private var glassComponents: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Componenti LiquidGlass")
                .font(AppTheme.Typography.title3)
                .sectionHeader()

            // Bottoni glass
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Bottoni")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                ZStack {
                    // Sfondo colorato per vedere l'effetto glass
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))

                    GlassEffectContainer {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Button("Primario") {}
                                .buttonStyle(LiquidGlassCapsuleButtonStyle())
                                .foregroundStyle(.white)

                            Button("Secondario") {}
                                .buttonStyle(LiquidGlassCapsuleButtonStyle())
                                .foregroundStyle(.white)

                            Button {} label: {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.white)
                                    .padding(AppTheme.Spacing.xs)
                            }
                            .glassEffect(.regular, in: Circle())
                        }
                    }
                }
            }

            // Card glass su sfondo
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Card Glass")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                ZStack {
                    LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

                    GlassCard {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("GlassCard")
                                    .font(AppTheme.Typography.headline)
                                Text("Componente riutilizzabile")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
        }
    }

    // MARK: - Confronto SwiftUI vs LiquidGlass

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    showComparison.toggle()
                }
            } label: {
                HStack {
                    Text("SwiftUI vs LiquidGlass")
                        .font(AppTheme.Typography.title3)
                    Spacer()
                    Image(systemName: showComparison ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if showComparison {
                comparisonTable
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feature").frame(maxWidth: .infinity, alignment: .leading)
                Text("SwiftUI").frame(width: 100)
                Text("Liq.Glass").frame(width: 100)
            }
            .font(AppTheme.Typography.footnote)
            .bold()
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(AppTheme.Spacing.sm)
            .background(AppTheme.Colors.secondaryBackground)

            // Righe
            ForEach(comparisonRows, id: \.feature) { row in
                HStack {
                    Text(row.feature)
                        .font(AppTheme.Typography.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    comparisonCell(row.swiftUI)
                        .frame(width: 100)

                    comparisonCell(row.liquidGlass)
                        .frame(width: 100)
                }
                .padding(AppTheme.Spacing.sm)
                .background(Color.clear)

                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func comparisonCell(_ value: ComparisonValue) -> some View {
        switch value {
        case .yes:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .no:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .partial:
            Image(systemName: "minus.circle.fill").foregroundStyle(.orange)
        case .text(let s):
            Text(s).font(AppTheme.Typography.caption2)
        }
    }

    private var comparisonRows: [(feature: String, swiftUI: ComparisonValue, liquidGlass: ComparisonValue)] {[
        ("Blur sfondo",          .yes,               .yes),
        ("Rifrazione luce",      .no,                .yes),
        ("Adattivo tema",        .partial,           .yes),
        ("Shape personalizzata", .partial,           .yes),
        ("Animazione materiale", .no,                .yes),
        ("iOS supportato",       .text("15+"),       .text("26+")),
        ("API",                  .text(".material"), .text(".glassEffect")),
    ]}
}

// MARK: - Helpers e Types

private enum ComparisonValue {
    case yes, no, partial
    case text(String)
}

enum GlassBackground: String, CaseIterable, Identifiable {
    case gradient, colorful, dark, light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradient: return "Gradient"
        case .colorful: return "Colorato"
        case .dark:     return "Scuro"
        case .light:    return "Chiaro"
        }
    }
}

enum GlassShape: String, CaseIterable, Identifiable {
    case roundedRect, capsule, circle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roundedRect: return "Rett."
        case .capsule:     return "Caps."
        case .circle:      return "Cerchio"
        }
    }
}

extension View {
    /// Applica la shape glass selezionata dall'utente.
    @ViewBuilder
    func applyGlassShape(_ shape: GlassShape) -> some View {
        switch shape {
        case .roundedRect:
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        case .capsule:
            self.glassEffect(.regular, in: Capsule())
        case .circle:
            self.glassEffect(.regular, in: Circle())
        }
    }
}

#Preview {
    NavigationStack {
        LiquidGlassShowcaseView()
    }
    .environment(AppState())
}
