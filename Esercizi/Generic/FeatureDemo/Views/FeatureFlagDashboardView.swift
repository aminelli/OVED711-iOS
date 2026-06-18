//
//  FeatureFlagDashboardView.swift
//  FeatureDemo
//
//  Dashboard di debug per la gestione manuale dei feature flag.
//
//  Questa view è visibile solo in DEBUG e STAGING build (vedi `CompileTimeFlags.showFeatureFlagDashboard`).
//  NON viene mai inclusa nei binary di produzione quando si usa `#if DEBUG` nell'entry point.
//
//  FUNZIONALITÀ:
//    - Visualizza tutti i flag con il loro valore corrente (remoto o override locale)
//    - Permette al QA di attivare/disattivare flag con un toggle
//    - Mostra quali flag hanno un override locale attivo (badge arancione)
//    - Pulsante "Reset Override" per rimuovere singoli override
//    - Pulsante "Reset Tutto" per riportare tutti i flag ai valori remoti
//    - Pulsante "Ricarica Config Remota" per forzare un fetch dal server
//
//  USO QA:
//  Il QA engineer usa questa dashboard per testare tutti i percorsi applicativi
//  senza dover aspettare modifiche nella configurazione remota o un nuovo build.

import SwiftUI

// MARK: - FeatureFlagDashboardView

struct FeatureFlagDashboardView: View {

    @Environment(AppDependencies.self) private var deps

    /// Valori correnti di tutti i flag, aggiornati dal servizio
    @State private var flagValues: [FeatureFlagKey: Bool] = [:]

    /// Flag che hanno un override locale attivo
    @State private var overriddenKeys: Set<FeatureFlagKey> = []

    /// `true` durante il fetch remoto forzato
    @State private var isFetching: Bool = false

    /// Messaggio di stato per operazioni come reset o fetch
    @State private var statusMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                // MARK: Sezione stato servizio
                Section {
                    RemoteConfigServiceStatusRow(
                        isLoaded: deps.homeViewModel.isFlagsLoaded,
                        overrideCount: overriddenKeys.count
                    )
                }

                // MARK: Flag raggruppati per categoria
                ForEach(ToggleCategory.allCases, id: \.self) { category in
                    let keysInCategory = FeatureFlagKey.allCases.filter { $0.category == category }

                    Section {
                        ForEach(keysInCategory, id: \.self) { key in
                            FlagRowView(
                                key: key,
                                value: flagValues[key] ?? key.defaultBoolValue,
                                hasOverride: overriddenKeys.contains(key),
                                onToggle: { newValue in
                                    Task { await setOverride(newValue, for: key) }
                                },
                                onResetOverride: {
                                    Task { await resetOverride(for: key) }
                                }
                            )
                        }
                    } header: {
                        CategoryHeaderView(category: category)
                    }
                }
            }
            .navigationTitle("🛠 Feature Flags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Pulsante reset di tutti gli override locali
                    Button("Reset Tutto") {
                        Task { await resetAllOverrides() }
                    }
                    .foregroundStyle(.red)
                    .disabled(overriddenKeys.isEmpty)

                    // Pulsante fetch remoto forzato
                    Button {
                        Task { await forceFetch() }
                    } label: {
                        if isFetching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise.icloud")
                        }
                    }
                    .disabled(isFetching)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Banner di messaggio di stato (es. "Override rimosso")
                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .padding(10)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: statusMessage)
        }
        .task {
            // Carica i valori dei flag all'apertura della dashboard
            await refreshFlagValues()
        }
    }

    // MARK: - Azioni

    /// Imposta un override locale per il flag e aggiorna la UI.
    private func setOverride(_ value: Bool, for key: FeatureFlagKey) async {
        // Imposta l'override nel composite adapter
        deps.compositeAdapter.setLocalOverride(value, for: key)

        // Invalida la cache nel servizio per propagare il cambiamento ai ViewModel
        await deps.featureFlagService.invalidateCache(for: key)

        // Aggiorna la UI della dashboard
        flagValues[key] = value
        overriddenKeys.insert(key)

        showStatus("Override impostato: \(key.displayName) = \(value ? "ON" : "OFF")")
    }

    /// Rimuove l'override locale per un flag specifico.
    private func resetOverride(for key: FeatureFlagKey) async {
        deps.compositeAdapter.removeLocalOverride(for: key)
        await deps.featureFlagService.invalidateCache(for: key)

        // Rileggi il valore dal servizio (ora tornerà al valore remoto)
        flagValues[key] = await deps.featureFlagService.isEnabled(key)
        overriddenKeys.remove(key)

        showStatus("Override rimosso: \(key.displayName)")
    }

    /// Rimuove tutti gli override locali.
    private func resetAllOverrides() async {
        deps.compositeAdapter.removeAllLocalOverrides()
        await deps.featureFlagService.invalidateAllCache()
        await refreshFlagValues()
        showStatus("Tutti gli override rimossi")
    }

    /// Forza un fetch dalla sorgente remota.
    private func forceFetch() async {
        isFetching = true
        await deps.featureFlagService.fetchRemoteConfiguration()
        await refreshFlagValues()
        isFetching = false
        showStatus("Configurazione remota aggiornata")
    }

    /// Aggiorna la snapshot dei valori di tutti i flag.
    private func refreshFlagValues() async {
        let values = await deps.featureFlagService.allCurrentValues()
        flagValues = values
        overriddenKeys = deps.compositeAdapter.allOverriddenKeys
    }

    /// Mostra un messaggio di stato temporaneo per 2 secondi.
    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            statusMessage = nil
        }
    }
}

// MARK: - Riga del flag nella lista

private struct FlagRowView: View {
    let key: FeatureFlagKey
    let value: Bool
    let hasOverride: Bool
    let onToggle: (Bool) -> Void
    let onResetOverride: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key.displayName)
                        .font(.subheadline)

                    // Badge arancione se c'è un override locale attivo
                    if hasOverride {
                        Text("OVERRIDE")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                // Chiave raw string del flag (utile per il debug)
                Text(key.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            // Toggle per attivare/disattivare il flag
            Toggle("", isOn: Binding(
                get: { value },
                set: { onToggle($0) }
            ))
            .labelsHidden()

            // Pulsante reset dell'override (visibile solo se esiste un override)
            if hasOverride {
                Button {
                    onResetOverride()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Header della categoria

private struct CategoryHeaderView: View {
    let category: ToggleCategory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.systemImage)
            Text(category.rawValue.uppercased())
        }
        .font(.caption.bold())
    }
}

// MARK: - Riga stato del servizio remote config

private struct RemoteConfigServiceStatusRow: View {
    let isLoaded: Bool
    let overrideCount: Int

    var body: some View {
        HStack {
            Image(systemName: isLoaded ? "checkmark.icloud.fill" : "icloud.slash.fill")
                .foregroundStyle(isLoaded ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(isLoaded ? "Config remota attiva" : "Usando valori di fallback")
                    .font(.subheadline)
                Text(overrideCount > 0
                     ? "\(overrideCount) override locale/i attivo/i"
                     : "Nessun override locale")
                    .font(.caption)
                    .foregroundStyle(overrideCount > 0 ? .orange : .secondary)
            }

            Spacer()
        }
    }
}
