//
//  Theme.swift
//  UIDemo
//
//  Design system centralizzato: colori, tipografia, spaziatura e animazioni.
//  Segue il principio di "design tokens" per garantire coerenza visiva
//  in tutta l'applicazione.
//

import SwiftUI

// MARK: - Namespace del Design System

/// Contenitore principale per tutti i token di design dell'applicazione.
/// Utilizza enum senza casi per creare namespace non istanziabili.
enum AppTheme {

    // MARK: - Colori Semantici

    /// Palette di colori semantici: definiti in base al ruolo, non al valore.
    /// In questo modo il theming (light/dark, accent) è gestito automaticamente.
    enum Colors {
        /// Colore primario dell'app, usato per azioni principali e brand
        static let primary = Color.blue
        /// Colore secondario, usato per elementi complementari
        static let secondary = Color.purple
        /// Colore di accento per highlight e badge
        static let accent = Color.orange
        /// Sfondo principale della schermata
        static let background = Color(.systemBackground)
        /// Sfondo secondario (cards, sezioni)
        static let secondaryBackground = Color(.secondarySystemBackground)
        /// Sfondo terziario (superfici sovrapposti)
        static let surface = Color(.tertiarySystemBackground)
        /// Testo su sfondo primario
        static let onPrimary = Color.white
        /// Colore di stato: successo
        static let success = Color.green
        /// Colore di stato: attenzione
        static let warning = Color.yellow
        /// Colore di stato: errore
        static let error = Color.red
        /// Testo principale
        static let textPrimary = Color(.label)
        /// Testo secondario, descrizioni e label
        static let textSecondary = Color(.secondaryLabel)
        /// Testo terziario, placeholder e hint
        static let textTertiary = Color(.tertiaryLabel)
        /// Colore separatore
        static let separator = Color(.separator)
    }

    // MARK: - Tipografia

    /// Scala tipografica basata sulle Dynamic Type categories di Apple.
    /// Garantisce accessibilità automatica con le impostazioni di sistema.
    enum Typography {
        static let largeTitle   = Font.largeTitle.weight(.bold)
        static let title        = Font.title.weight(.bold)
        static let title2       = Font.title2.weight(.semibold)
        static let title3       = Font.title3.weight(.semibold)
        static let headline     = Font.headline
        static let body         = Font.body
        static let callout      = Font.callout
        static let subheadline  = Font.subheadline
        static let footnote     = Font.footnote
        static let caption      = Font.caption
        static let caption2     = Font.caption2

        /// Font monospace per la visualizzazione di codice
        static let code = Font.system(.caption, design: .monospaced)
    }

    // MARK: - Spaziatura

    /// Scala di spaziatura basata su multipli di 4pt (base unit).
    /// Usare sempre questi valori invece di numeri arbitrari.
    enum Spacing {
        static let xxs: CGFloat  = 4
        static let xs: CGFloat   = 8
        static let sm: CGFloat   = 12
        static let md: CGFloat   = 16
        static let lg: CGFloat   = 24
        static let xl: CGFloat   = 32
        static let xxl: CGFloat  = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Border Radius

    /// Raggi di arrotondamento standardizzati.
    enum CornerRadius {
        static let small:  CGFloat = 8
        static let medium: CGFloat = 12
        static let large:  CGFloat = 16
        static let xLarge: CGFloat = 24
        static let pill:   CGFloat = 9999 // Per elementi "pillola"
    }

    // MARK: - Animazioni

    /// Preset di animazione per garantire coerenza nel motion design.
    enum Animation {
        /// Animazione rapida per feedback immediato (pulsanti, toggle)
        static let fast    = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8)
        /// Animazione standard per transizioni UI
        static let standard = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
        /// Animazione lenta per apertura di pannelli e modal
        static let slow    = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.7)
        /// Animazione per elementi che rimbalzano (onboarding, celebrations)
        static let bouncy  = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - ViewModifiers del Design System

/// Stile "card" riutilizzabile: sfondo, ombra e padding standardizzati.
struct CardModifier: ViewModifier {
    var padding: CGFloat = AppTheme.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

/// Stile per un bottone primario con colore e forma standardizzati.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                // Scala leggermente al press per feedback aptico visivo
                AppTheme.Colors.primary
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.Animation.fast, value: configuration.isPressed)
    }
}

/// Stile per un bottone secondario (outline) con bordo e sfondo trasparente.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(AppTheme.Colors.primary)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                Capsule()
                    .strokeBorder(AppTheme.Colors.primary, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AppTheme.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - View Extensions per convenienza

extension View {
    /// Applica lo stile card standardizzato (sfondo + ombra + padding).
    func cardStyle(padding: CGFloat = AppTheme.Spacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// Applica un'etichetta di sezione con stile headline.
    func sectionHeader() -> some View {
        self
            .font(AppTheme.Typography.title3)
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chiave Environment per il tema

/// Consente di iniettare il tema corrente nell'albero di view tramite @Environment.
/// Estendibile in futuro per supportare temi personalizzati dall'utente.
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeConfig()
}

/// Configurazione del tema runtime (utile per white-labeling o preferenze utente).
struct ThemeConfig {
    var accentColor: Color = AppTheme.Colors.primary
    var useGlassEffect: Bool = true
    var animationsEnabled: Bool = true
}

extension EnvironmentValues {
    /// Accesso al tema corrente: `@Environment(\.appTheme) var theme`
    var appTheme: ThemeConfig {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
