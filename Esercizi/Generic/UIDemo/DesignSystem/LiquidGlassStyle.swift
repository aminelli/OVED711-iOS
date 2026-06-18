//
//  LiquidGlassStyle.swift
//  UIDemo
//
//  Showcase degli effetti LiquidGlass introdotti con iOS 26.
//  LiquidGlass è il nuovo linguaggio visivo di Apple: un materiale
//  traslucente con rifrazione dinamica della luce, ispirato al vetro liquido.
//
//  Riferimento WWDC 2025: "Meet Liquid Glass" e "Build a SwiftUI app with the new design"
//

import SwiftUI

// MARK: - ViewModifier LiquidGlass

/// Applica l'effetto glass material canonico di iOS 26 con shape configurabile.
/// `.glassEffect()` è il modificatore nativo introdotto in iOS 26.
struct LiquidGlassModifier: ViewModifier {
    /// Indica se l'effetto è interattivo (scala e intensità reagiscono al press)
    var isInteractive: Bool = false
    /// Raggio di arrotondamento degli angoli della forma glass
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large
    /// Intensità del tint colorato sovrapposto al glass
    var tintOpacity: Double = 0.0
    var tintColor: Color = .clear

    func body(content: Content) -> some View {
        content
            // .glassEffect() è il modificatore iOS 26 per il materiale LiquidGlass.
            // Accetta una Shape per definire il contorno del materiale.
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            // Overlay opzionale per aggiungere un tint colorato sopra il glass
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tintColor.opacity(tintOpacity))
            )
    }
}

/// Applica glass effect con forma a capsula (usato per bottoni e chip).
struct LiquidGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: Capsule())
    }
}

/// Applica glass effect con forma circolare (usato per icone e avatar).
struct LiquidGlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: Circle())
    }
}

// MARK: - View Extension per LiquidGlass

extension View {

    /// Applica il materiale LiquidGlass con angoli arrotondati.
    /// - Parameter cornerRadius: Raggio degli angoli (default: `AppTheme.CornerRadius.large`)
    func liquidGlass(cornerRadius: CGFloat = AppTheme.CornerRadius.large) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    /// Applica il materiale LiquidGlass con forma a capsula.
    func liquidGlassCapsule() -> some View {
        modifier(LiquidGlassCapsuleModifier())
    }

    /// Applica il materiale LiquidGlass con forma circolare.
    func liquidGlassCircle() -> some View {
        modifier(LiquidGlassCircleModifier())
    }

    /// Applica il materiale LiquidGlass con un tint colorato.
    /// Utile per distinguere visivamente categorie o stati.
    func liquidGlassTinted(
        color: Color,
        opacity: Double = 0.15,
        cornerRadius: CGFloat = AppTheme.CornerRadius.large
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            tintOpacity: opacity,
            tintColor: color
        ))
    }
}

// MARK: - LiquidGlassButton Style

/// ButtonStyle che sfrutta LiquidGlass per creare bottoni con effetto vetro.
/// Al press, la vista scala leggermente per un feedback visivo elegante.
struct LiquidGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = AppTheme.CornerRadius.large

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            // Applica il glass come sfondo nativo del bottone
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            // Feedback visivo: leggera scala al press
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppTheme.Animation.fast, value: configuration.isPressed)
    }
}

/// ButtonStyle capsule con LiquidGlass.
struct LiquidGlassCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.xs)
            .glassEffect(.regular, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppTheme.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - GlassCard Component

/// Card riutilizzabile con sfondo LiquidGlass.
/// Combina il materiale glass con un layout flessibile per contenuti arbitrari.
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        // GlassEffectContainer coordina i livelli glass di tutti i figli,
        // garantendo la corretta composizione dei layer traslucenti.
        GlassEffectContainer {
            content
                .padding(AppTheme.Spacing.md)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - GlassToolbar Component

/// Toolbar fluttuante con effetto LiquidGlass, tipicamente posizionata
/// in sovrimpressione sul contenuto principale (es. bottom bar floating).
struct GlassToolbar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            content
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        // Usa una capsula come contenitore glass per la toolbar
        .glassEffect(.regular, in: Capsule())
        // Ombra leggera per distaccarla visivamente dal contenuto sottostante
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}
