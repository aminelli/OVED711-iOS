//
//  ABIStabilityViewModel.swift
//  AppDemo
//
//  ViewModel che orchestra la logica della demo ABI Stability.
//  Usa il modello di concorrenza di Swift 6: `@MainActor` per garantire
//  che tutte le modifiche alle proprietà `@Published` avvengano sul
//  thread principale, evitando data race rilevati da Swift Concurrency.
//

import SwiftUI
import Observation

// MARK: - Sezione della demo

/// Rappresenta una sezione didattica della demo.
///
/// `@frozen` perché questa enum è interna alla demo e non crescerà.
/// È un esempio concreto di quando usare `@frozen` anche su tipi interni:
/// quando si sa con certezza che il tipo non cambierà.
@frozen
enum DemoSection: String, CaseIterable, Identifiable {
    case intro         = "Introduzione"
    case frozenEnum    = "@frozen enum"
    case frozenStruct  = "@frozen struct"
    case inlinable     = "@inlinable / @usableFromInline"
    case resilient     = "Tipo resiliente (confronto)"

    // `id` conforme a Identifiable: necessario per ForEach in SwiftUI.
    var id: String { rawValue }

    /// Icona SF Symbols associata alla sezione.
    var iconName: String {
        switch self {
        case .intro:        return "info.circle.fill"
        case .frozenEnum:   return "lock.fill"
        case .frozenStruct: return "square.3.layers.3d.down.left.fill"
        case .inlinable:    return "arrow.down.doc.fill"
        case .resilient:    return "arrow.triangle.2.circlepath"
        }
    }

    /// Colore tematico della sezione.
    var tintColor: Color {
        switch self {
        case .intro:        return .blue
        case .frozenEnum:   return .purple
        case .frozenStruct: return .orange
        case .inlinable:    return .green
        case .resilient:    return .gray
        }
    }
}

// MARK: - ViewModel

/// ViewModel per la schermata principale della demo ABI Stability.
///
/// Adotta il protocollo `Observable` (introdotto in Swift 5.9 / iOS 17)
/// invece di `ObservableObject`/`@Published`, in linea con le best
/// practices Swift 6: riduce il boilerplate e migliora le performance
/// grazie al tracking granulare delle dipendenze.
///
/// `@MainActor` assicura che tutte le mutazioni avvengano sul thread
/// principale, senza necessità di `DispatchQueue.main.async` manuale.
@MainActor
@Observable
final class ABIStabilityViewModel {

    // MARK: Stato UI

    /// Sezione attualmente selezionata nella demo.
    var selectedSection: DemoSection = .intro

    /// Forma geometrica scelta dall'utente per la demo @frozen enum.
    var selectedShape: Shape = .circle

    /// Dimensione (lato/raggio) per il calcolo del perimetro.
    var shapeSize: Double = 10.0

    /// Punto corrente per la demo @frozen struct.
    ///
    /// `StablePoint` ha proprietà `let` (frozen layout immutabile):
    /// non è possibile ottenere un `Binding<Double>` direttamente su `point.x`.
    /// Esponiamo quattro proprietà proxy `var` che ricostruiscono il `StablePoint`
    /// ad ogni modifica — pattern corretto con tipi @frozen immutabili in SwiftUI.
    var point: StablePoint { StablePoint(x: pointX, y: pointY) }

    /// Coordinata X del primo punto — mutabile, usata come binding per lo Slider.
    var pointX: Double = 3.0

    /// Coordinata Y del primo punto — mutabile, usata come binding per lo Slider.
    var pointY: Double = 4.0

    /// Secondo punto da sommare al primo.
    var secondPoint: StablePoint { StablePoint(x: secondPointX, y: secondPointY) }

    /// Coordinata X del secondo punto — mutabile, usata come binding per lo Slider.
    var secondPointX: Double = 1.0

    /// Coordinata Y del secondo punto — mutabile, usata come binding per lo Slider.
    var secondPointY: Double = 1.0

    // MARK: Valori calcolati (derivati dallo stato)

    /// Descrizione del perimetro calcolata tramite funzione `@inlinable`.
    ///
    /// Usa `perimeterDescription(for:size:)` che è marcata `@inlinable`:
    /// in un contesto reale cross-modulo il compilatore copierebbe il corpo
    /// di questa funzione nel modulo chiamante per ottimizzarla.
    var perimeterText: String {
        perimeterDescription(for: selectedShape, size: shapeSize)
    }

    /// Distanza dall'origine del punto corrente.
    var distanceText: String {
        String(format: "StablePoint(%.1f, %.1f) → distanza = %.4f",
               point.x, point.y, point.distanceFromOrigin)
    }

    /// Risultato della somma vettoriale tra i due punti.
    var sumPointText: String {
        let sum = point + secondPoint
        return String(format: "(%.1f, %.1f) + (%.1f, %.1f) = (%.1f, %.1f)",
                      point.x, point.y,
                      secondPoint.x, secondPoint.y,
                      sum.x, sum.y)
    }

    // MARK: Testi esplicativi

    /// Restituisce il testo descrittivo per la sezione selezionata.
    var sectionExplanation: String {
        switch selectedSection {
        case .intro:
            return """
            La **ABI Stability** (Application Binary Interface Stability) è stata \
            introdotta in Swift 5.0 (Xcode 10.2, iOS 12.2).

            Prima di Swift 5.0, ogni app doveva **includere una copia della \
            Standard Library** nel suo bundle (+7 MB). Con la ABI Stability, \
            la Standard Library è distribuita con **il sistema operativo** e \
            condivisa tra tutte le app, come accade da sempre con Objective-C.

            Gli attributi chiave che rendono possibile tutto ciò sono:
            `@frozen`, `@inlinable`, `@usableFromInline`, `@_fixed_layout`.
            """
        case .frozenEnum:
            return """
            Un enum `@frozen` ha un **layout fisso**: il compilatore sa \
            esattamente quanti casi esistono ora e in futuro.

            **Vantaggi:**
            - Switch esaustivi senza `@unknown default`
            - Ottimizzazioni di dimensione in memoria
            - Nessun overhead di resilienza a runtime

            **Vincolo:** aggiungere casi in futuro è un **ABI-breaking change**.
            """
        case .frozenStruct:
            return """
            Una struct `@frozen` ha un **layout in memoria fisso**: \
            l'ordine e il tipo delle stored properties non cambieranno mai.

            **Vantaggi:**
            - Il compilatore del client può accedere ai campi direttamente \
              senza accessor virtualizzati.
            - Abilita ottimizzazioni aggressive (SIMD, loop unrolling).
            - Interoperabilità C/C++ senza bridging overhead.

            **Vincolo:** nessuna aggiunta/riordino di stored properties \
            nelle versioni successive.
            """
        case .inlinable:
            return """
            `@inlinable` rende il **corpo di una funzione** parte dell'ABI \
            pubblica del modulo. Il compilatore può copiarlo nel modulo \
            chiamante e ottimizzarlo nel contesto d'uso.

            `@usableFromInline` permette a simboli `internal` di essere \
            visibili a funzioni `@inlinable` dello stesso modulo.

            **Attenzione:** il corpo di una funzione `@inlinable` diventa \
            un contratto pubblico: modificarlo può rompere la compatibilità \
            binaria dei client già compilati.
            """
        case .resilient:
            return """
            Un tipo **resiliente** (senza `@frozen`) mantiene compatibilità \
            binaria attraverso l'evoluzione della libreria.

            Il compilatore inserisce un livello di indirezione che permette \
            di aggiungere casi/proprietà nelle versioni future senza rompere \
            i client già compilati.

            **Costo:** piccolo overhead a runtime per accesso indiretto. \
            È il comportamento **predefinito** per i tipi `public`.
            """
        }
    }
}
