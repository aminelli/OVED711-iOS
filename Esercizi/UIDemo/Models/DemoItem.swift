//
//  DemoItem.swift
//  UIDemo
//
//  Modelli di dati usati nelle varie demo dell'applicazione.
//  Conformità a Identifiable, Hashable e Codable per massima flessibilità
//  con SwiftUI List, ForEach, NavigationStack e persistenza.
//

import SwiftUI

// MARK: - DemoItem

/// Elemento generico usato nelle liste e nella demo di navigazione.
struct DemoItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var iconName: String
    var color: String // Stored as hex string per Codable conformance
    var category: DemoCategory
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        iconName: String = "star.fill",
        color: String = "blue",
        category: DemoCategory = .general,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.color = color
        self.category = category
        self.isFavorite = isFavorite
    }

    /// Colore SwiftUI derivato dal nome stringa
    var swiftUIColor: Color {
        switch color {
        case "blue":   return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green":  return .green
        case "red":    return .red
        case "teal":   return .teal
        case "pink":   return .pink
        default:       return .blue
        }
    }
}

// MARK: - DemoCategory

/// Categorie per raggruppare gli elementi demo.
enum DemoCategory: String, CaseIterable, Codable, Identifiable {
    case general    = "Generale"
    case uiKit      = "UIKit"
    case swiftUI    = "SwiftUI"
    case animation  = "Animazione"
    case networking = "Networking"

    var id: String { rawValue }

    /// Icona SF Symbols associata alla categoria
    var iconName: String {
        switch self {
        case .general:    return "square.grid.2x2"
        case .uiKit:      return "uiwindow.split.2x1"
        case .swiftUI:    return "swift"
        case .animation:  return "sparkles"
        case .networking: return "network"
        }
    }
}

// MARK: - Dati di esempio

extension DemoItem {
    /// Collezione di elementi demo predefiniti per popolare le liste nell'app.
    static let samples: [DemoItem] = [
        DemoItem(
            title: "UIHostingController",
            subtitle: "Integra SwiftUI in UIKit",
            iconName: "rectangle.split.2x1",
            color: "blue",
            category: .uiKit
        ),
        DemoItem(
            title: "UIViewRepresentable",
            subtitle: "Porta UIKit in SwiftUI",
            iconName: "arrow.left.arrow.right",
            color: "purple",
            category: .uiKit
        ),
        DemoItem(
            title: "@Observable",
            subtitle: "State management moderno",
            iconName: "waveform",
            color: "orange",
            category: .swiftUI
        ),
        DemoItem(
            title: "NavigationStack",
            subtitle: "Navigazione type-safe",
            iconName: "map",
            color: "teal",
            category: .swiftUI
        ),
        DemoItem(
            title: "LiquidGlass",
            subtitle: "Il nuovo materiale iOS 26",
            iconName: "drop.fill",
            color: "blue",
            category: .swiftUI
        ),
        DemoItem(
            title: "Gesture Recognizers",
            subtitle: "Pan, Pinch, Rotation",
            iconName: "hand.draw",
            color: "pink",
            category: .uiKit
        ),
        DemoItem(
            title: "Compositional Layout",
            subtitle: "UICollectionView avanzato",
            iconName: "square.grid.3x3",
            color: "green",
            category: .uiKit
        ),
        DemoItem(
            title: "Accessibility",
            subtitle: "VoiceOver e Dynamic Type",
            iconName: "accessibility",
            color: "orange",
            category: .general
        ),
    ]
}

// MARK: - GemTransformState

/// Stato per la demo delle trasformazioni gesture (drag, pinch, rotation).
/// Rinominato da GestureState per evitare conflitto con @GestureState di SwiftUI.
struct GemTransformState {
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var offset: CGSize = .zero
    var lastScale: CGFloat = 1.0
    var lastRotation: Angle = .zero

    /// Resetta tutti i valori allo stato iniziale
    mutating func reset() {
        scale = 1.0
        rotation = .zero
        offset = .zero
        lastScale = 1.0
        lastRotation = .zero
    }
}
