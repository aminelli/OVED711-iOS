//
//  GestureLayoutView.swift
//  UIDemo
//
//  Dimostra gesture recognizer avanzati in SwiftUI e UIKit:
//
//  SwiftUI Gestures:
//  - DragGesture: trascinamento con offset
//  - MagnifyGesture (ex MagnificationGesture): pinch-to-zoom
//  - RotationGesture: rotazione a due dita
//  - TapGesture: singolo e doppio tap
//  - LongPressGesture: pressione prolungata
//  - Gesture combinati con .simultaneously e .sequenced
//
//  UIKit (tramite UIViewRepresentable):
//  - UIPanGestureRecognizer: disegno libero
//  - Tela di disegno con Core Graphics
//

import SwiftUI

// MARK: - GestureLayoutView

struct GestureLayoutView: View {

    @Environment(AppState.self) private var appState

    /// Stato del target interattivo (la "gemma" trascinabile)
    @State private var gemState = GemTransformState()
    /// Tab della demo selezionato
    @State private var selectedDemo: GestureDemo = .transform

    // MARK: Stato Tela di disegno UIKit
    @State private var strokeColor: Color = .blue
    @State private var lineWidth: CGFloat = 4
    @State private var strokeCount: Int = 0
    @State private var canvasAction: CanvasAction = .none

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {

                // Segmented control per scegliere la demo
                Picker("Demo", selection: $selectedDemo) {
                    ForEach(GestureDemo.allCases) { demo in
                        Text(demo.title).tag(demo)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.md)

                switch selectedDemo {
                case .transform:
                    transformGestureDemo
                case .combined:
                    combinedGestureDemo
                case .canvas:
                    canvasDemo
                }
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .animation(AppTheme.Animation.standard, value: selectedDemo)
        }
        .navigationTitle("Gestures")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Demo 1: Transform Gesture

    /// Dimostra DragGesture, MagnifyGesture e RotationGesture su un singolo oggetto.
    /// I gesture vengono combinati con .simultaneously per gestirli in parallelo.
    private var transformGestureDemo: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Trascina, pizzica e ruota la gemma")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal)

            // Area interattiva
            ZStack {
                // Sfondo della zona di interazione
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xLarge)
                    .fill(AppTheme.Colors.secondaryBackground)
                    .frame(height: 360)

                // La "gemma" interattiva
                GemView()
                    .scaleEffect(gemState.scale)
                    .rotationEffect(gemState.rotation)
                    .offset(gemState.offset)
                    // DragGesture: aggiorna l'offset in tempo reale
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                gemState.offset = CGSize(
                                    width: value.translation.width,
                                    height: value.translation.height
                                )
                            }
                            .onEnded { _ in
                                // Spring back al centro con animazione
                                withAnimation(AppTheme.Animation.bouncy) {
                                    gemState.offset = .zero
                                }
                            }
                    )
                    // MagnifyGesture: scala la gemma
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                gemState.scale = gemState.lastScale * value.magnification
                            }
                            .onEnded { value in
                                gemState.lastScale = gemState.scale
                                // Limita la scala tra 0.5x e 3x
                                withAnimation(AppTheme.Animation.standard) {
                                    gemState.scale = gemState.scale.clamped(to: 0.5...3.0)
                                    gemState.lastScale = gemState.scale
                                }
                            }
                    )
                    // RotationGesture: ruota la gemma
                    .gesture(
                        RotationGesture()
                            .onChanged { angle in
                                gemState.rotation = gemState.lastRotation + angle
                            }
                            .onEnded { angle in
                                gemState.lastRotation = gemState.rotation
                            }
                    )
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .clipped()

            // Statistiche in tempo reale
            HStack(spacing: AppTheme.Spacing.md) {
                statBadge(label: "Scala", value: String(format: "%.1fx", gemState.scale), icon: "arrow.up.left.and.arrow.down.right")
                statBadge(label: "Rotazione", value: String(format: "%.0f°", gemState.rotation.degrees), icon: "rotate.right")
                statBadge(label: "X", value: String(format: "%.0f", gemState.offset.width), icon: "arrow.left.arrow.right")
                statBadge(label: "Y", value: String(format: "%.0f", gemState.offset.height), icon: "arrow.up.arrow.down")
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            Button("Reset trasformazioni") {
                withAnimation(AppTheme.Animation.bouncy) {
                    gemState.reset()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Demo 2: Gesture combinati

    /// Dimostra TapGesture, LongPressGesture e gesture sequenziali/simultanei.
    private var combinedGestureDemo: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Esplora i tipi di gesture")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal)

            TapDemoView()
            LongPressDemoView()
            SequencedGestureView()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Demo 3: Tela di disegno UIKit

    /// Integra la tela di disegno UIKit (UIPanGestureRecognizer + CAShapeLayer).
    private var canvasDemo: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Toolbar di controllo
            HStack {
                // Picker colore
                ForEach([Color.blue, .red, .green, .orange, .purple], id: \.self) { color in
                    Button {
                        strokeColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: strokeColor == color ? 3 : 0)
                            )
                    }
                }

                Spacer()

                Text("\(strokeCount) tratt\(strokeCount == 1 ? "o" : "i")")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // Slider spessore tratto
            HStack {
                Image(systemName: "pencil.tip")
                    .font(.caption)
                Slider(value: $lineWidth, in: 1...20) {
                    Text("Spessore")
                }
                Image(systemName: "pencil.tip")
                    .font(.title3)
            }
            .padding(.horizontal, AppTheme.Spacing.md)

            // La tela UIKit avvolta da UIViewRepresentable
            CustomCanvasViewRepresentable(
                strokeColor: $strokeColor,
                lineWidth: $lineWidth,
                strokeCount: $strokeCount,
                canvasAction: $canvasAction
            )
            .frame(height: 300)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .strokeBorder(AppTheme.Colors.separator, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.md)

            // Azioni sulla tela
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    canvasAction = .undo
                } label: {
                    Label("Annulla", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(strokeCount == 0)

                Button {
                    canvasAction = .clear
                } label: {
                    Label("Cancella tutto", systemImage: "trash")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(strokeCount == 0)
            }
        }
    }

    // MARK: - Helpers UI

    private func statBadge(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(AppTheme.Typography.footnote)
                .bold()
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }
}

// MARK: - GemView

/// L'oggetto interattivo del demo trasformazioni: un cristallo esagonale.
private struct GemView: View {
    var body: some View {
        ZStack {
            // Forma esagonale tramite clipShape con Path
            LinearGradient(
                colors: [.blue, .purple, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(HexagonShape())
            .frame(width: 100, height: 100)
            .shadow(color: .blue.opacity(0.4), radius: 20)

            Image(systemName: "diamond.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

/// Forma esagonale custom tramite SwiftUI Path.
private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        // 6 vertici dell'esagono
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - .pi / 6
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - TapDemoView

private struct TapDemoView: View {
    @State private var tapCount = 0
    @State private var doubleTapCount = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            // Singolo tap
            VStack {
                Text("Tap singolo: \(tapCount)")
                    .font(AppTheme.Typography.caption)
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.primary.opacity(0.15))
                    .frame(height: 60)
                    .overlay(Image(systemName: "hand.point.up.left.fill").foregroundStyle(AppTheme.Colors.primary))
                    .onTapGesture {
                        withAnimation(AppTheme.Animation.fast) { tapCount += 1 }
                    }
            }

            // Doppio tap con animazione di scala
            VStack {
                Text("Doppio tap: \(doubleTapCount)")
                    .font(AppTheme.Typography.caption)
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .fill(AppTheme.Colors.secondary.opacity(0.15))
                    .frame(height: 60)
                    .overlay(Image(systemName: "hand.tap.fill").foregroundStyle(AppTheme.Colors.secondary))
                    .scaleEffect(scale)
                    .onTapGesture(count: 2) {
                        doubleTapCount += 1
                        withAnimation(AppTheme.Animation.bouncy) {
                            scale = 1.3
                        }
                        withAnimation(AppTheme.Animation.standard.delay(0.15)) {
                            scale = 1.0
                        }
                    }
            }
        }
    }
}

// MARK: - LongPressDemoView

private struct LongPressDemoView: View {
    @State private var isLongPressing = false
    @State private var longPressCount = 0
    @GestureState private var isPressing = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Long press: \(longPressCount)")
                .font(AppTheme.Typography.caption)

            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(isPressing ? AppTheme.Colors.accent : AppTheme.Colors.accent.opacity(0.15))
                .frame(height: 60)
                .overlay(
                    Label(
                        isPressing ? "Rilascia!" : "Tieni premuto",
                        systemImage: isPressing ? "hand.raised.fill" : "hand.raised"
                    )
                    .foregroundStyle(isPressing ? .white : AppTheme.Colors.accent)
                    .animation(AppTheme.Animation.fast, value: isPressing)
                )
                // @GestureState si resetta automaticamente quando il gesture termina
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .updating($isPressing) { value, state, _ in
                            state = value
                        }
                        .onEnded { _ in
                            longPressCount += 1
                        }
                )
                .animation(AppTheme.Animation.fast, value: isPressing)
        }
    }
}

// MARK: - SequencedGestureView

/// Dimostra gesture.sequenced(before:): prima un longPress, poi un drag.
private struct SequencedGestureView: View {
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Gesture sequenziale: LongPress → Drag")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            let longPress = LongPressGesture(minimumDuration: 0.5)
                .updating($isDetectingLongPress) { value, state, _ in
                    state = value
                }
                .onEnded { _ in completedLongPress = true }

            let drag = DragGesture()
                .onChanged { value in
                    if completedLongPress {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(AppTheme.Animation.bouncy) {
                        dragOffset = .zero
                        completedLongPress = false
                    }
                }

            Circle()
                .fill(completedLongPress
                      ? AppTheme.Colors.success
                      : (isDetectingLongPress ? AppTheme.Colors.accent : AppTheme.Colors.primary))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: completedLongPress ? "lock.open.fill" : "lock.fill")
                        .foregroundStyle(.white)
                )
                .offset(dragOffset)
                .gesture(longPress.sequenced(before: drag))
                .animation(AppTheme.Animation.fast, value: isDetectingLongPress)
                .animation(AppTheme.Animation.fast, value: completedLongPress)
        }
    }
}

// MARK: - GestureDemo Enum

private enum GestureDemo: String, CaseIterable, Identifiable {
    case transform, combined, canvas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transform: return "Transform"
        case .combined:  return "Tap/Press"
        case .canvas:    return "Canvas UIKit"
        }
    }
}

// MARK: - Comparable extension per Comparable clamping

extension Comparable {
    /// Limita il valore all'interno di un range chiuso.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    NavigationStack {
        GestureLayoutView()
    }
    .environment(AppState())
}
