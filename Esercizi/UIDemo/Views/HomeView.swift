//
//  HomeView.swift
//  UIDemo
//
//  Schermata principale dell'app: hub di navigazione verso tutte le demo.
//  Utilizza ScrollView + LazyVGrid per un layout responsivo,
//  con LiquidGlass per l'header e le card delle sezioni.
//

import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    /// Accesso allo stato globale dell'app iniettato nell'environment
    @Environment(AppState.self) private var appState
    /// Accesso al tema corrente
    @Environment(\.appTheme) private var theme
    /// Namespace per le animazioni matched geometry (hero transition)
    @Namespace private var heroNamespace

    /// Definisce le sezioni della home con titolo, icona e tab di destinazione
    private let sections: [(title: String, icon: String, tab: AppTab, description: String, color: Color)] = [
        ("Hybrid UI",      "rectangle.split.2x1.fill", .hybrid,        "UIHostingController & UIViewRepresentable",  .blue),
        ("State Mgmt",     "waveform.path",             .stateDemo,     "@Observable, @State, @Binding, @Environment", .purple),
        ("Navigation",     "map.fill",                  .navigation,    "NavigationStack e deep linking",              .teal),
        ("Gestures",       "hand.draw.fill",            .gestures,      "Gesture SwiftUI + UIKit pan/pinch",           .orange),
        ("Accessibility",  "accessibility",             .accessibility, "VoiceOver, Dynamic Type, A11y",               .green),
        ("Liquid Glass",   "drop.fill",                 .liquidGlass,   "Il materiale iOS 26",                         .cyan),
        ("Design System",  "paintbrush.fill",           .designSystem,  "Token, tipografia e animazioni",              .pink),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // MARK: Header con LiquidGlass
                heroHeader

                // MARK: Banner counter globale
                if appState.globalCounter > 0 {
                    counterBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: Griglia sezioni
                sectionsGrid

                Spacer(minLength: AppTheme.Spacing.xxxl)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .navigationTitle("UIDemo")
        .navigationBarTitleDisplayMode(.large)
        // Pulsante reset nella navigation bar
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(AppTheme.Animation.standard) {
                        appState.resetDemo()
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(appState.globalCounter == 0)
            }
        }
    }

    // MARK: - Hero Header

    /// Header della home con sfondo LiquidGlass e info utente.
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Sfondo gradiente
            LinearGradient(
                colors: [theme.accentColor, theme.accentColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xLarge))
            .frame(height: 200)

            // Icona decorativa in background
            Image(systemName: "swift")
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(.white.opacity(0.15))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, AppTheme.Spacing.lg)

            // Contenuto testuale sovrapposto
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("UIDemo")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(.white)

                Text("iOS 26 · Swift 6.3 · SwiftUI + UIKit")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                // Badge LiquidGlass su sfondo colorato
                Text("LiquidGlass Ready")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    .background(.white.opacity(0.25))
                    .clipShape(Capsule())
            }
            .padding(AppTheme.Spacing.lg)
        }
    }

    // MARK: - Counter Banner

    /// Banner animato che mostra il contatore globale quando > 0.
    private var counterBanner: some View {
        HStack {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(AppTheme.Colors.accent)
            Text("Interazioni globali: **\(appState.globalCounter)**")
                .font(AppTheme.Typography.subheadline)
            Spacer()
            // Bottone per incrementare direttamente dalla home
            Button {
                appState.incrementCounter()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .strokeBorder(AppTheme.Colors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Sections Grid

    /// Griglia 2 colonne con le card di navigazione verso le demo.
    @ViewBuilder
    private var sectionsGrid: some View {
        Text("Esplora le demo")
            .font(AppTheme.Typography.title3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppTheme.Colors.textPrimary)

        // LazyVGrid a 2 colonne adattive: si ridimensiona con la finestra
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
                GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
            ],
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(sections, id: \.tab) { section in
                SectionCard(
                    title: section.title,
                    description: section.description,
                    iconName: section.icon,
                    color: section.color
                ) {
                    // Naviga al tab corrispondente
                    withAnimation(AppTheme.Animation.standard) {
                        appState.selectedTab = section.tab
                    }
                }
            }
        }
    }
}

// MARK: - SectionCard

/// Card di navigazione con icona, titolo e colore tematico.
/// Supporta sia lo stile LiquidGlass (iOS 26) sia il fallback card standard.
private struct SectionCard: View {
    let title: String
    let description: String
    let iconName: String
    let color: Color
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                // Icona in cerchio colorato
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(color)
                }

                Spacer()

                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.md)
            .frame(height: 140)
        }
        // Stile: se abilitato usa LiquidGlass, altrimenti card standard
        .buttonStyle(theme.useGlassEffect ? AnyButtonStyle(LiquidGlassButtonStyle()) : AnyButtonStyle(CardButtonStyle(color: color)))
        // Accessibilità: label combinata per VoiceOver
        .accessibilityLabel("\(title): \(description)")
        .accessibilityHint("Tocca per esplorare la demo")
    }
}

// MARK: - AnyButtonStyle (type erasure per ButtonStyle)

/// Type-erased ButtonStyle per selezionare lo stile a runtime.
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

/// ButtonStyle standard per le card (fallback senza LiquidGlass).
private struct CardButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppTheme.Animation.fast, value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppState())
}
