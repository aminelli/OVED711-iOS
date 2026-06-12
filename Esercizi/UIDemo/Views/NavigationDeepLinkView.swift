//
//  NavigationDeepLinkView.swift
//  UIDemo
//
//  Dimostra la navigazione avanzata con NavigationStack e deep linking:
//
//  1. NavigationStack con NavigationPath type-safe
//  2. navigationDestination(for:) per mappare tipi a destinazioni
//  3. Navigazione programmatica (push/pop/pop-to-root)
//  4. Gestione URL di deep link con openURL e onOpenURL
//  5. Costruzione di URL deep link per testing
//
//  Riferimento: WWDC 2022 "The SwiftUI cookbook for navigation"
//

import SwiftUI

// MARK: - NavigationDeepLinkView

struct NavigationDeepLinkView: View {

    /// Router iniettato tramite environment (vedi UIDemoApp)
    @Environment(NavigationRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    /// Testo del deep link personalizzato da testare
    @State private var customDeepLink: String = "uidemo://navigate/detail/SwiftUI%20Demo"
    /// Indica se il campo deep link è in editing
    @State private var isEditingURL: Bool = false

    var body: some View {
        // Usa @Bindable per creare binding da @Observable
        let bindableRouter = Bindable(router)

        NavigationStack(path: bindableRouter.path) {
            List {

                // MARK: Sezione navigazione programmatica
                Section {
                    ForEach(navigationItems) { item in
                        NavigationLink(value: item.destination) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                } header: {
                    Text("Navigazione Programmatica")
                } footer: {
                    Text("Ogni link usa navigationDestination(for:) per mappare una destinazione type-safe.")
                        .font(AppTheme.Typography.caption)
                }

                // MARK: Sezione stack info
                Section {
                    HStack {
                        Label("Livelli nello stack", systemImage: "square.stack")
                        Spacer()
                        Text("\(router.path.count)")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .contentTransition(.numericText())
                    }

                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            router.goToRoot()
                        }
                    } label: {
                        Label("Pop to Root", systemImage: "arrow.uturn.left.circle.fill")
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                    .disabled(router.path.isEmpty)

                } header: {
                    Text("Stack di Navigazione")
                }

                // MARK: Sezione deep linking
                Section {
                    deepLinkBuilder
                } header: {
                    Text("Deep Linking")
                } footer: {
                    Text("Schema: uidemo://navigate/<destinazione>[/<parametro>]")
                        .font(AppTheme.Typography.code)
                }

            }
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.large)
            // Registra le destinazioni di navigazione
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            // Gestisce i deep link in arrivo dall'esterno dell'app
            .onOpenURL { url in
                let handled = router.handle(url: url)
                if handled {
                    appState.showFeedback("Deep link gestito: \(url.host ?? "")")
                }
            }
        }
    }

    // MARK: - Deep Link Builder

    private var deepLinkBuilder: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Testa un deep link URL")
                .font(AppTheme.Typography.subheadline)

            TextField("uidemo://navigate/...", text: $customDeepLink)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(AppTheme.Typography.code)

            // Esempi rapidi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(deepLinkExamples, id: \.self) { example in
                        Button(example) {
                            customDeepLink = example
                        }
                        .font(AppTheme.Typography.caption)
                        .padding(.horizontal, AppTheme.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                guard let url = URL(string: customDeepLink) else { return }
                openURL(url)
            } label: {
                Label("Apri URL", systemImage: "link.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(URL(string: customDeepLink) == nil)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Destination View Factory

    /// Restituisce la view corrispondente alla destinazione di navigazione.
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .itemDetail(let id, let title):
            ItemDetailView(id: id, title: title)
        case .category(let name):
            CategoryView(name: name)
        case .settings:
            SettingsDestinationView()
        case .profile:
            ProfileDestinationView()
        case .deepLinkLanding(let message):
            DeepLinkLandingView(message: message)
        }
    }

    // MARK: - Data

    private var navigationItems: [NavItem] {[
        NavItem(title: "Dettaglio Item",    icon: "doc.text",          destination: .itemDetail(id: UUID(), title: "Elemento di esempio")),
        NavItem(title: "Categoria SwiftUI", icon: "swift",             destination: .category(name: "SwiftUI")),
        NavItem(title: "Categoria UIKit",   icon: "uiwindow.split.2x1",destination: .category(name: "UIKit")),
        NavItem(title: "Impostazioni",      icon: "gear",              destination: .settings),
        NavItem(title: "Profilo",           icon: "person.circle",     destination: .profile),
    ]}

    private let deepLinkExamples = [
        "uidemo://navigate/settings",
        "uidemo://navigate/profile",
        "uidemo://navigate/category/SwiftUI",
        "uidemo://navigate/detail/LiquidGlass",
    ]
}

// MARK: - NavItem helper

private struct NavItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: NavigationDestination
}

// MARK: - Destinazioni

/// View di dettaglio generico per un DemoItem.
struct ItemDetailView: View {
    let id: UUID
    let title: String
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.primary)

            Text(title)
                .font(AppTheme.Typography.title)

            Text("ID: \(id.uuidString.prefix(8))...")
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .font(.system(.footnote, design: .monospaced))

            // Navigazione in profondità (push di un altro livello)
            Button {
                router.navigate(to: .itemDetail(
                    id: UUID(),
                    title: "\(title) → Sub-dettaglio"
                ))
            } label: {
                Label("Apri sub-dettaglio", systemImage: "arrow.right.circle")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Pop to Root") {
                withAnimation(AppTheme.Animation.standard) {
                    router.goToRoot()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(AppTheme.Spacing.xl)
        .navigationTitle("Dettaglio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// View categoria con lista di item filtrati.
struct CategoryView: View {
    let name: String
    @Environment(NavigationRouter.self) private var router

    private var items: [DemoItem] {
        DemoItem.samples.filter { $0.category.rawValue == name || name == "UIKit" && $0.category == .uiKit || name == "SwiftUI" && $0.category == .swiftUI }
    }

    var body: some View {
        List(items.isEmpty ? DemoItem.samples : items) { item in
            Button {
                router.navigate(to: .itemDetail(id: item.id, title: item.title))
            } label: {
                Label(item.title, systemImage: item.iconName)
            }
        }
        .navigationTitle(name)
    }
}

/// Schermata impostazioni (placeholder).
struct SettingsDestinationView: View {
    var body: some View {
        List {
            Section("Aspetto") {
                Label("Tema", systemImage: "paintbrush")
                Label("LiquidGlass", systemImage: "drop.fill")
            }
            Section("Account") {
                Label("Profilo", systemImage: "person.circle")
                Label("Privacy", systemImage: "lock.shield")
            }
        }
        .navigationTitle("Impostazioni")
    }
}

/// Schermata profilo (placeholder).
struct ProfileDestinationView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: appState.userProfile.avatarSystemName)
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.Colors.primary)

            Text(appState.userProfile.name)
                .font(AppTheme.Typography.title)

            if appState.userProfile.isPremium {
                Label("Premium", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding()
        .navigationTitle("Profilo")
    }
}

/// Schermata di landing per i deep link non riconosciuti.
struct DeepLinkLandingView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.accent)

            Text("Deep Link Ricevuto")
                .font(AppTheme.Typography.title)

            Text(message)
                .font(AppTheme.Typography.code)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding()
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        }
        .padding()
        .navigationTitle("Deep Link")
    }
}

#Preview {
    NavigationDeepLinkView()
        .environment(NavigationRouter())
        .environment(AppState())
}
