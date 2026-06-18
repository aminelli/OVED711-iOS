//
//  ContentView.swift
//  UIDemo
//
//  Punto di ingresso della UI: TabView principale che ospita tutte le demo.
//
//  Usa la nuova sintassi Tab (iOS 18+) per dichiarare i tab in modo type-safe.
//  Lo stato del tab selezionato è gestito da AppState (@Observable) e
//  condiviso tramite environment, rendendo possibile la navigazione
//  programmatica verso un tab specifico da qualsiasi punto dell'app.
//
//  Il NavigationRouter è iniettato nell'environment per il deep linking.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    /// Accesso all'AppState globale per controllare il tab selezionato
    @Environment(AppState.self) private var appState
    /// Router per la navigazione e il deep linking
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        // Usa @Bindable per creare il binding selectedTab da @Observable
        let bindableState = Bindable(appState)

        TabView(selection: bindableState.selectedTab) {

            // MARK: Home Tab
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack {
                    HomeView()
                }
            }

            // MARK: Hybrid UI Tab
            Tab(AppTab.hybrid.title, systemImage: AppTab.hybrid.systemImage, value: AppTab.hybrid) {
                NavigationStack {
                    HybridArchitectureView()
                }
            }

            // MARK: State Management Tab
            Tab(AppTab.stateDemo.title, systemImage: AppTab.stateDemo.systemImage, value: AppTab.stateDemo) {
                NavigationStack {
                    StateManagementView()
                }
            }

            // MARK: Navigation & Deep Link Tab
            // Questo tab usa il NavigationRouter condiviso per gestire
            // la NavigationStack e il deep linking tramite URL scheme.
            Tab(AppTab.navigation.title, systemImage: AppTab.navigation.systemImage, value: AppTab.navigation) {
                NavigationDeepLinkView()
                    .environment(router)
            }

            // MARK: Gestures Tab
            Tab(AppTab.gestures.title, systemImage: AppTab.gestures.systemImage, value: AppTab.gestures) {
                NavigationStack {
                    GestureLayoutView()
                }
            }

            // MARK: Accessibility Tab
            Tab(AppTab.accessibility.title, systemImage: AppTab.accessibility.systemImage, value: AppTab.accessibility) {
                NavigationStack {
                    AccessibilityView()
                }
            }

            // MARK: LiquidGlass Tab
            Tab(AppTab.liquidGlass.title, systemImage: AppTab.liquidGlass.systemImage, value: AppTab.liquidGlass) {
                NavigationStack {
                    LiquidGlassShowcaseView()
                }
            }

            // MARK: Design System Tab
            Tab(AppTab.designSystem.title, systemImage: AppTab.designSystem.systemImage, value: AppTab.designSystem) {
                NavigationStack {
                    DesignSystemView()
                }
            }
        }
        // Banner di feedback globale (toast) sovrapposto alla TabView
        .overlay(alignment: .top) {
            if let message = appState.feedbackMessage {
                FeedbackBanner(message: message)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(AppTheme.Animation.standard, value: appState.feedbackMessage)
        // Inietta il tema nell'environment per tutte le view figlie
        .environment(\.appTheme, ThemeConfig(
            accentColor: AppTheme.Colors.primary,
            useGlassEffect: appState.glassEffectsEnabled,
            animationsEnabled: appState.animationsEnabled
        ))
    }
}

// MARK: - FeedbackBanner

/// Banner di feedback temporaneo visualizzato in cima alla schermata.
/// Scompare automaticamente dopo 2 secondi (gestito da AppState.showFeedback).
private struct FeedbackBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppTheme.Typography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(NavigationRouter())
}
