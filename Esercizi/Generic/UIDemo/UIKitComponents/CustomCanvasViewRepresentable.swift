//
//  CustomCanvasViewRepresentable.swift
//  UIDemo
//
//  Esempio di UIViewRepresentable: tela di disegno con Core Graphics.
//  Dimostra come usare UIBezierPath e CAShapeLayer per disegno vettoriale
//  ad alte prestazioni, integrato in SwiftUI tramite UIViewRepresentable.
//
//  Dimostra anche la comunicazione bidirezionale:
//  - SwiftUI -> UIKit: tramite Binding (colore, spessore tratto)
//  - UIKit -> SwiftUI: tramite Binding (numero di tratti disegnati)
//

import SwiftUI
import UIKit

// MARK: - DrawingCanvas (UIView)

/// UIView personalizzata che gestisce il disegno con UIPanGestureRecognizer.
/// Ogni tratto è un UIBezierPath aggiunto a un CAShapeLayer separato
/// per permettere l'undo (rimozione dell'ultimo layer) in modo efficiente.
final class DrawingCanvasView: UIView {

    // MARK: - Stato interno
    private var layers: [CAShapeLayer] = []
    private var currentPath: UIBezierPath?
    private var currentLayer: CAShapeLayer?

    // MARK: - Configurazione pubblica
    var strokeColor: UIColor = .systemBlue {
        didSet { currentLayer?.strokeColor = strokeColor.cgColor }
    }
    var lineWidth: CGFloat = 4 {
        didSet { currentLayer?.lineWidth = lineWidth }
    }

    // MARK: - Callback verso SwiftUI
    /// Chiamata ogni volta che il numero di tratti cambia
    var onStrokeCountChanged: ((Int) -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesture()
        backgroundColor = .clear
        // Rende la view accessibile come "Tela di disegno"
        isAccessibilityElement = true
        accessibilityLabel = "Tela di disegno"
        accessibilityHint = "Scorri per disegnare"
        accessibilityTraits = .allowsDirectInteraction
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    // MARK: - Setup

    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        // Consente di disegnare anche con più dita (es. Apple Pencil + touch)
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    // MARK: - Gesture Handler

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            // Inizia un nuovo path e un nuovo layer per questo tratto
            let path = UIBezierPath()
            path.move(to: point)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let layer = CAShapeLayer()
            layer.strokeColor = strokeColor.cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = lineWidth
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.frame = bounds

            self.layer.addSublayer(layer)
            layers.append(layer)

            currentPath = path
            currentLayer = layer

        case .changed:
            // Aggiunge il punto corrente al path e aggiorna il layer
            currentPath?.addLine(to: point)
            currentLayer?.path = currentPath?.cgPath

        case .ended, .cancelled:
            // Finalizza il tratto e notifica SwiftUI
            onStrokeCountChanged?(layers.count)
            currentPath = nil
            currentLayer = nil

        default:
            break
        }
    }

    // MARK: - Azioni pubbliche

    /// Rimuove l'ultimo tratto disegnato (undo).
    func undoLastStroke() {
        guard !layers.isEmpty else { return }
        let last = layers.removeLast()
        last.removeFromSuperlayer()
        onStrokeCountChanged?(layers.count)
    }

    /// Cancella tutti i tratti (reset).
    func clearAll() {
        layers.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()
        onStrokeCountChanged?(0)
    }
}

// MARK: - SwiftUI Wrapper

/// Wrapper SwiftUI per DrawingCanvasView.
/// Espone il colore, lo spessore e il numero di tratti come Binding.
struct CustomCanvasViewRepresentable: UIViewRepresentable {

    @Binding var strokeColor: Color
    @Binding var lineWidth: CGFloat
    @Binding var strokeCount: Int
    /// Riferimento al coordinator per chiamare undo/clear dall'esterno
    @Binding var canvasAction: CanvasAction

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> DrawingCanvasView {
        let canvas = DrawingCanvasView()
        // Mantiene il riferimento alla UIView nel coordinator per le azioni esterne
        context.coordinator.canvas = canvas
        canvas.onStrokeCountChanged = { count in
            strokeCount = count
        }
        return canvas
    }

    func updateUIView(_ canvas: DrawingCanvasView, context: Context) {
        // Sincronizza le proprietà di configurazione
        canvas.strokeColor = UIColor(strokeColor)
        canvas.lineWidth = lineWidth

        // Gestisce le azioni triggerate da SwiftUI (undo, clear)
        switch canvasAction {
        case .none:
            break
        case .undo:
            canvas.undoLastStroke()
            canvasAction = .none // Resetta l'azione dopo l'esecuzione
        case .clear:
            canvas.clearAll()
            canvasAction = .none
        }
    }

    // MARK: - Coordinator

    final class Coordinator {
        weak var canvas: DrawingCanvasView?
    }
}

// MARK: - CanvasAction

/// Azioni che SwiftUI può inviare al canvas UIKit.
/// Pattern "command/action binding" per comunicazione unidirezionale SwiftUI→UIKit.
enum CanvasAction {
    case none
    case undo
    case clear
}
