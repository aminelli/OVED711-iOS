//
//  HybridArchitectureView.swift
//  UIDemo
//
//  Dimostra l'architettura ibrida SwiftUI + UIKit:
//  1. UIViewRepresentable: UIScrollView paginato (carosello) in SwiftUI
//  2. UIViewControllerRepresentable: UICollectionView compositional in SwiftUI
//  3. UIHostingController: come portare una SwiftUI View in UIKit (simulato)
//
//  Questi pattern sono fondamentali per:
//  - Migrazioni incrementali da UIKit a SwiftUI
//  - Riuso di componenti UIKit legacy in app SwiftUI nuove
//  - Accesso a funzionalità UIKit non ancora disponibili in SwiftUI
//

import SwiftUI

// MARK: - HybridArchitectureView

struct HybridArchitectureView: View {

    @Environment(AppState.self) private var appState

    /// Pagina corrente del carosello UIScrollView
    @State private var currentCarouselPage: Int = 0
    /// Item selezionato dalla CollectionView UIKit
    @State private var selectedItem: DemoItem? = nil
    /// Sezione correntemente visualizzata
    @State private var expandedSection: HybridSection? = .uiViewRepresentable

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {

                // MARK: - Sezione 1: UIViewRepresentable
                sectionToggle(
                    section: .uiViewRepresentable,
                    title: "UIViewRepresentable",
                    subtitle: "UIScrollView paginato → SwiftUI",
                    icon: "arrow.left.arrow.right",
                    color: .blue
                ) {
                    uiViewRepresentableDemo
                }

                // MARK: - Sezione 2: UIViewControllerRepresentable
                sectionToggle(
                    section: .uiViewControllerRepresentable,
                    title: "UIViewControllerRepresentable",
                    subtitle: "UICollectionView compositional → SwiftUI",
                    icon: "square.grid.3x3",
                    color: .purple
                ) {
                    uiViewControllerRepresentableDemo
                }

                // MARK: - Sezione 3: UIHostingController
                sectionToggle(
                    section: .uiHostingController,
                    title: "UIHostingController",
                    subtitle: "SwiftUI View → UIKit ViewController",
                    icon: "arrow.right.circle.fill",
                    color: .orange
                ) {
                    uiHostingControllerDemo
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Hybrid UI")
        .navigationBarTitleDisplayMode(.large)
        // Sheet con dettaglio item selezionato dalla CollectionView
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
        }
    }

    // MARK: - UIViewRepresentable Demo

    /// Mostra il carosello UIScrollView paginato avvolto da UIViewRepresentable.
    private var uiViewRepresentableDemo: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Il componente UIKit avvolto: altezza fissa, larghezza flessibile
            PagingCarouselRepresentable(
                pages: CarouselPage.samples,
                currentPage: $currentCarouselPage
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))

            // Indicatore di pagina SwiftUI sincronizzato tramite Binding
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0..<CarouselPage.samples.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentCarouselPage
                              ? AppTheme.Colors.primary
                              : AppTheme.Colors.separator)
                        .frame(width: index == currentCarouselPage ? 20 : 8, height: 8)
                        .animation(AppTheme.Animation.fast, value: currentCarouselPage)
                }
            }

            Text("Pagina \(currentCarouselPage + 1) di \(CarouselPage.samples.count)")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - UIViewControllerRepresentable Demo

    /// Mostra la UICollectionView con Compositional Layout avvolta in SwiftUI.
    private var uiViewControllerRepresentableDemo: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let selected = selectedItem {
                // Banner che mostra l'item selezionato
                HStack {
                    Image(systemName: selected.iconName)
                        .foregroundStyle(selected.swiftUIColor)
                    Text("Selezionato: **\(selected.title)**")
                        .font(AppTheme.Typography.subheadline)
                    Spacer()
                    Button("Dettaglio") {
                        // Il binding selectedItem apre automaticamente il sheet
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.primary)
                }
                .padding(AppTheme.Spacing.sm)
                .background(selected.swiftUIColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            }

            // La UICollectionView UIKit: altezza fissa, contenuto scrollabile
            CollectionViewControllerRepresentable(
                items: DemoItem.samples,
                onSelect: { item in
                    selectedItem = item
                    appState.incrementCounter()
                }
            )
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        }
    }

    // MARK: - UIHostingController Demo

    /// Spiega come si usa UIHostingController in un contesto UIKit reale,
    /// mostrando uno snippet di codice e una preview della view guest.
    private var uiHostingControllerDemo: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Snippet di codice (simulato)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Codice UIKit (Swift)")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(hostingControllerSnippet)
                    .font(AppTheme.Typography.code)
                    .foregroundStyle(.green)
                    .padding(AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
            }

            Text("Preview della view ospitata:")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            // Anteprima della SwiftUI View che verrebbe ospitata in UIKit
            SwiftUIGuestView()
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        }
    }

    // MARK: - Section Toggle Helper

    /// Costruisce una sezione espandibile/collassabile con header e contenuto.
    @ViewBuilder
    private func sectionToggle<Content: View>(
        section: HybridSection,
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Header cliccabile
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: expandedSection == section ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .padding(AppTheme.Spacing.md)
            }
            .buttonStyle(.plain)

            // Contenuto espandibile
            if expandedSection == section {
                content()
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }

    // MARK: - Helpers

    private var hostingControllerSnippet: String {
"""
// In un UIViewController UIKit:
let swiftUIView = SwiftUIGuestView()
let hostingVC = UIHostingController(
    rootView: swiftUIView
)
addChild(hostingVC)
view.addSubview(hostingVC.view)
hostingVC.didMove(toParent: self)
"""
    }
}

// MARK: - HybridSection Enum

private enum HybridSection: Equatable {
    case uiViewRepresentable
    case uiViewControllerRepresentable
    case uiHostingController
}

// MARK: - SwiftUIGuestView

/// View SwiftUI di esempio che verrebbe ospitata in un UIHostingController.
private struct SwiftUIGuestView: View {
    @State private var count = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("SwiftUI in UIKit")
                    .font(AppTheme.Typography.headline)
                Text("Questa view vive in un UIHostingController")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
            // Bottone con @State locale: funziona normalmente anche se ospitato in UIKit
            Button {
                withAnimation(AppTheme.Animation.bouncy) { count += 1 }
            } label: {
                Text("\(count)")
                    .font(AppTheme.Typography.title2)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.Colors.primary)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .contentTransition(.numericText())
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.primary.opacity(0.08))
    }
}

// MARK: - ItemDetailSheet

/// Foglio modale con il dettaglio di un DemoItem selezionato dalla CollectionView.
private struct ItemDetailSheet: View {
    let item: DemoItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Icona grande
                Image(systemName: item.iconName)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(item.swiftUIColor)
                    .frame(width: 100, height: 100)
                    .background(item.swiftUIColor.opacity(0.15))
                    .clipShape(Circle())

                Text(item.title)
                    .font(AppTheme.Typography.title)

                Text(item.subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Categoria: \(item.category.rawValue)")
                    .font(AppTheme.Typography.footnote)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    .background(item.swiftUIColor.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(AppTheme.Spacing.xl)
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HybridArchitectureView()
    }
    .environment(AppState())
}
