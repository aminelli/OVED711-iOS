//
//  ABIStableTypes.swift
//  AppDemo
//
//  Questo file simula il "lato framework" della ABI Stability.
//  In un progetto reale questi tipi vivrebbero in un target separato
//  (es. un Xcode Framework o un package Swift) distribuito come dylib.
//  Qui li raccogliamo nello stesso target per scopi didattici, ma tutti
//  i concetti applicati (attributi, annotazioni) sono identici a quelli
//  usati nella Standard Library di Apple e nei suoi framework pubblici.
//

import Foundation

// MARK: - @frozen enum

/// Rappresenta la forma geometrica supportata dalla libreria.
///
/// L'attributo `@frozen` comunica al compilatore che questo enum
/// **non riceverà mai nuovi casi** nelle versioni future della libreria.
/// Questo permette due vantaggi fondamentali per la ABI Stability:
///
/// 1. Il codice client può usare uno `switch` **esaustivo** senza
///    `@unknown default`, perché il compilatore sa già tutti i casi.
/// 2. Il compilatore può ottimizzare la rappresentazione in memoria
///    del tipo senza riservarsi spazio per casi futuri sconosciuti.
///
/// **Attenzione:** aggiungere un caso a un enum `@frozen` dopo la
/// pubblicazione è un **ABI-breaking change** e causerebbe crash
/// a runtime nelle app compilate con la versione precedente.
@frozen
public enum Shape: String, CaseIterable, Sendable {
    case circle    = "Cerchio"
    case square    = "Quadrato"
    case triangle  = "Triangolo"

    /// Restituisce il nome del simbolo SF Symbols associato alla forma.
    ///
    /// Marcata `@inlinable` perché il suo corpo è abbastanza semplice
    /// da essere copiato (inlinato) direttamente nel codice chiamante
    /// durante la compilazione, eliminando l'overhead della chiamata.
    @inlinable
    public var symbolName: String {
        switch self {
        case .circle:   return "circle.fill"
        case .square:   return "square.fill"
        case .triangle: return "triangle.fill"
        }
    }
}

// MARK: - @frozen struct

/// Rappresenta un punto 2D con coordinate in virgola mobile.
///
/// L'attributo `@frozen` su una struct garantisce che il **layout
/// in memoria** (ordine e tipo delle stored properties) non cambierà
/// mai. Questo consente:
///
/// - Accesso diretto ai campi senza passare per accessor virtuali.
/// - Inlining aggressivo delle funzioni che operano su questo tipo.
/// - Interoperabilità C/Objective-C senza bridging overhead.
///
/// **Regola:** una struct `@frozen` non può aggiungere o riordinare
/// stored properties in versioni successive della libreria.
@frozen
public struct StablePoint: Equatable, Hashable, Sendable {
    // Le proprietà devono rimanere in questo ordine e con questi tipi
    // per non rompere l'ABI. Qualsiasi riordino è un ABI-breaking change.
    public let x: Double
    public let y: Double

    /// Inizializzatore pubblico: necessario perché le struct `@frozen`
    /// devono esporre un init esplicito se usate cross-modulo, dato che
    /// il memberwise init sintetizzato NON è considerato parte dell'ABI
    /// stabile (la sua firma dipende dalle stored properties).
    @inlinable
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Calcola la distanza euclidea dall'origine (0, 0).
    ///
    /// `@inlinable` permette al compilatore di sostituire questa chiamata
    /// con il codice equivalente a `sqrt(x*x + y*y)` nel sito di chiamata,
    /// sfruttando le ottimizzazioni SIMD o FPU disponibili sul device.
    @inlinable
    public var distanceFromOrigin: Double {
        (x * x + y * y).squareRoot()
    }

    /// Somma vettoriale di due punti.
    ///
    /// Operatore `@inlinable` per evitare overhead di chiamata su
    /// operazioni critiche nelle hot path grafiche.
    @inlinable
    public static func + (lhs: StablePoint, rhs: StablePoint) -> StablePoint {
        StablePoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

// MARK: - @usableFromInline internal helper

/// Calcola il perimetro approssimato di una forma dati i parametri.
///
/// `@usableFromInline` rende questa funzione `internal` **visibile**
/// dal codice `@inlinable` dello stesso modulo (o di un modulo che
/// importa questo come framework). Senza questa annotazione, un corpo
/// `@inlinable` non potrebbe chiamare simboli interni perché il corpo
/// viene copiato nel modulo del chiamante, dove quei simboli non esistono.
@usableFromInline
internal func approximatePerimeter(shape: Shape, size: Double) -> Double {
    switch shape {
    case .circle:   return Double.pi * size          // π·d
    case .square:   return 4.0 * size
    case .triangle: return 3.0 * size                // triangolo equilatero
    }
}

/// Restituisce una descrizione formattata del perimetro.
///
/// Funzione pubblica e `@inlinable`: il suo corpo è copiato nel modulo
/// client. Può chiamare `approximatePerimeter` perché quella è
/// `@usableFromInline`.
@inlinable
public func perimeterDescription(for shape: Shape, size: Double) -> String {
    let value = approximatePerimeter(shape: shape, size: size)
    // String(format:) è disponibile cross-modulo perché Foundation è ABI-stabile
    return String(format: "%@ → perimetro ≈ %.2f", shape.rawValue, value)
}

// MARK: - Confronto NON-frozen (resilience overhead)

/// Forma geometrica NON congelata: versione di confronto didattico.
///
/// Senza `@frozen` il compilatore deve trattare questo enum come
/// **resiliente**: si riserva la possibilità che versioni future
/// della libreria aggiungano casi. Questo introduce:
///
/// - Obbligo di `@unknown default` negli switch.
/// - Un livello di indirezione in memoria (il compilatore non conosce
///   la dimensione esatta a compile-time del modulo chiamante).
/// - Impossibilità di inlinare switch completi senza sacrificare
///   la correttezza forward-compatible.
public enum ResilientShape: String, CaseIterable, Sendable {
    case circle   = "Cerchio (resiliente)"
    case square   = "Quadrato (resiliente)"
    case triangle = "Triangolo (resiliente)"
    // In futuro potremmo aggiungere `.hexagon` senza rompere l'ABI,
    // ma i client dovrebbero gestire `@unknown default`.
}
