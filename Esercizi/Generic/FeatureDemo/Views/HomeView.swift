//
//  HomeView.swift
//  FeatureDemo
//
//  Schermata principale che mostra i feature flag in azione.
//
//  Ogni sezione della view è condizionata da un tipo diverso di toggle:
//    - Banner manutenzione  → Ops Toggle (ot_maintenanceMode)
//    - Layout redesignato   → Release Toggle (rt_redesignedHome)
//    - Pulsante checkout    → Experiment Toggle (et_checkoutButtonColor)
//    - Sezione premium      → Permission Toggle (pt_premiumContent)
//
//  La View osserva il `HomeViewModel` (@Observable) tramite il meccanismo
//  nativo di SwiftUI: ogni accesso a una proprietà @Observable durante
//  il rendering registra automaticamente la dipendenza.

import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    // Il ViewModel è osservato automaticamente da SwiftUI (@Observable)
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        let vm = deps.homeViewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Ops Toggle — Banner manutenzione
                    // Visibile solo quando `ot_maintenanceMode` è attivo
                    if vm.showMaintenanceBanner {
                        MaintenanceBannerView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 24) {

                        // MARK: Indicatore stato caricamento remote config
                        RemoteConfigStatusView(
                            isLoaded: vm.isFlagsLoaded,
                            isLoading: vm.isLoadingRemoteConfig
                        )

                        // MARK: Release Toggle — Layout redesignato
                        if vm.useRedesignedHome {
                            RedesignedHeroSection()
                        } else {
                            ClassicHeroSection()
                        }

                        Divider()

                        // MARK: Experiment Toggle — Pulsante checkout
                        CheckoutSection(viewModel: vm)

                        Divider()

                        // MARK: Release Toggle — Nuovo onboarding
                        if vm.showNewOnboarding {
                            NewOnboardingBadge()
                        }

                        // MARK: Permission Toggle — Contenuto premium
                        if vm.isPremiumEnabled {
                            PremiumContentSection()
                        } else {
                            UpgradeToPremiumSection()
                        }

                        // MARK: Experiment Toggle — Algoritmo raccomandazioni
                        RecommendationSection(algorithm: vm.recommendationAlgorithmLabel)
                    }
                    .padding()
                }
            }
            .navigationTitle("FeatureDemo")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.3), value: vm.showMaintenanceBanner)
            .animation(.easeInOut(duration: 0.3), value: vm.isFlagsLoaded)
        }
    }
}

// MARK: - Ops Toggle: Banner manutenzione

private struct MaintenanceBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Manutenzione in corso")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Alcune funzionalità potrebbero essere temporaneamente non disponibili.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding()
        .background(Color.orange)
        // [ot_maintenanceMode] — Ops Toggle: questo banner appare solo quando
        // il team operativo attiva il flag per segnalare una situazione di emergenza
    }
}

// MARK: - Stato Remote Config

private struct RemoteConfigStatusView: View {
    let isLoaded: Bool
    let isLoading: Bool

    var body: some View {
        HStack {
            // Indicatore visivo dello stato del fetch remoto
            Image(systemName: isLoaded ? "checkmark.icloud.fill" : "icloud.slash.fill")
                .foregroundStyle(isLoaded ? .green : .secondary)
            Text(isLoaded
                 ? "Config remota caricata"
                 : (isLoading ? "Caricamento config remota…" : "Config in attesa"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoading && !isLoaded {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Release Toggle: Layout CLASSICO (rt_redesignedHome = false)

private struct ClassicHeroSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // [rt_redesignedHome = false] — Release Toggle: layout originale
            Label("Versione Classica", systemImage: "house")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.15))
                .clipShape(Capsule())

            HStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text("Benvenuto in FeatureDemo")
                        .font(.title2.bold())
                    Text("Esplora i feature flag in azione")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Release Toggle: Layout REDESIGNATO (rt_redesignedHome = true)

private struct RedesignedHeroSection: View {
    var body: some View {
        VStack(spacing: 16) {
            // [rt_redesignedHome = true] — Release Toggle: nuovo design in fase di rollout
            Label("Nuovo Design", systemImage: "sparkles")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())

            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text("FeatureDemo")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Il futuro dei feature flag su iOS 26")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding()
            }
        }
    }
}

// MARK: - Experiment Toggle: Sezione checkout

private struct CheckoutSection: View {
    let viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Etichetta che mostra la variante attiva dell'esperimento
            HStack {
                Text("Pulsante Checkout")
                    .font(.headline)
                Spacer()
                ExperimentBadge(
                    variant: viewModel.useGreenButton ? "Variante B (verde)" : "Variante A (blu)",
                    flagKey: "et_checkout_button_color"
                )
            }

            Text("Questo pulsante partecipa a un A/B test sul colore. Il 50% degli utenti vede la variante verde, il 50% quella blu.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // [et_checkoutButtonColor] — Experiment Toggle
            // Variante A (false) = blu, Variante B (true) = verde
            Button {
                Task { await viewModel.trackCheckoutButtonTapped() }
            } label: {
                Label("Procedi all'acquisto", systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.checkoutButtonColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.4), value: viewModel.useGreenButton)
        }
    }
}

// MARK: - Badge variante esperimento

struct ExperimentBadge: View {
    let variant: String
    let flagKey: String

    var body: some View {
        Text(variant)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.purple.opacity(0.15))
            .foregroundStyle(.purple)
            .clipShape(Capsule())
    }
}

// MARK: - Release Toggle: Badge nuovo onboarding

private struct NewOnboardingBadge: View {
    var body: some View {
        // [rt_newOnboarding = true] — Release Toggle: badge visibile solo agli utenti
        // che fanno parte del gruppo di rollout del nuovo onboarding
        HStack {
            Image(systemName: "rocket.fill")
                .foregroundStyle(.orange)
            Text("Hai accesso al nuovo onboarding! Completa il tour per sbloccare tutte le funzionalità.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Inizia") {}
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.orange)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Permission Toggle: Contenuto premium (pt_premiumContent = true)

private struct PremiumContentSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // [pt_premiumContent = true] — Permission Toggle: solo per abbonati
            Label("Contenuto Premium", systemImage: "crown.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            ForEach(["Analisi avanzate", "Export illimitato", "Supporto prioritario"], id: \.self) { item in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(item)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.yellow.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Permission Toggle: Upgrade a premium (pt_premiumContent = false)

private struct UpgradeToPremiumSection: View {
    var body: some View {
        // [pt_premiumContent = false] — Permission Toggle: utente non abbonato
        HStack {
            VStack(alignment: .leading) {
                Label("Sblocca Premium", systemImage: "lock.fill")
                    .font(.headline)
                Text("Accedi a contenuti esclusivi e funzionalità avanzate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Abbonati") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Experiment Toggle: Sezione raccomandazioni

private struct RecommendationSection: View {
    let algorithm: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // [et_recommendationAlgorithm] — Experiment Toggle
            HStack {
                Text("Raccomandazioni per te")
                    .font(.headline)
                Spacer()
                ExperimentBadge(variant: algorithm, flagKey: "et_recommendation_algorithm")
            }
            Text("L'algoritmo attivo è: \(algorithm). I risultati varieranno tra le varianti dell'esperimento.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
