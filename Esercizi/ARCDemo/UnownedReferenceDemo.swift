//
//  UnownedReferenceDemo.swift
//  ArcDemo
//
//  Scenario 3: riferimenti `unowned` — quando il ciclo di vita è garantito.
//  Come `weak`, `unowned` NON incrementa il reference count. A differenza di `weak`,
//  NON è opzionale: presuppone che l'oggetto puntato esista per TUTTA la vita
//  dell'oggetto che lo referenzia. Se l'oggetto venisse deallocato prima, si
//  avrebbe un crash (accesso a memoria non valida).
//

import SwiftUI

// MARK: - Modello

/// Rappresenta un utente autenticato nell'applicazione.
final class AuthenticatedUser {

    /// Identificatore univoco dell'utente.
    let userID: String

    /// Il profilo è creato insieme all'utente e non può esistere senza di lui.
    /// Usiamo `var` perché il profilo viene assegnato dopo l'inizializzazione.
    var profile: UserProfile?

    init(userID: String) {
        self.userID = userID
        print("✅ AuthenticatedUser '\(userID)' allocato")
    }

    deinit {
        print("♻️ AuthenticatedUser '\(userID)' deallocato")
    }
}

/// Rappresenta il profilo associato a un utente autenticato.
/// Il profilo NON può esistere senza un utente: il suo ciclo di vita è
/// strettamente subordinato a quello di `AuthenticatedUser`.
final class UserProfile {

    /// Dati del profilo.
    let displayName: String

    /// Riferimento UNOWNED all'utente proprietario.
    /// Usiamo `unowned` (e non `weak`) perché:
    ///   1. Il profilo viene sempre deallocato prima o insieme all'utente.
    ///   2. Non ha senso che esista un profilo senza utente → no Optional.
    ///   3. Evita il costo dell'unwrap opzionale ad ogni accesso.
    unowned let owner: AuthenticatedUser

    init(displayName: String, owner: AuthenticatedUser) {
        self.displayName = displayName
        self.owner = owner
        print("✅ UserProfile '\(displayName)' allocato (owner: \(owner.userID))")
    }

    deinit {
        print("♻️ UserProfile '\(displayName)' deallocato")
    }

    /// Restituisce una stringa descrittiva usando il riferimento unowned.
    func description() -> String {
        // Accesso diretto senza unwrap: sicuro perché `owner` è garantito in vita
        return "\(displayName) (userID: \(owner.userID))"
    }
}

// MARK: - ViewModel

/// ViewModel che dimostra `unowned` e il confronto con `weak`.
@Observable
final class UnownedReferenceViewModel {

    /// Log degli eventi ARC.
    var log: [String] = []

    /// Crea un utente con il suo profilo usando `unowned`, poi rilascia tutto.
    /// Entrambi i deinit devono essere chiamati: nessun retain cycle.
    func demonstrateUnowned() {
        log.removeAll()
        appendLog("--- Creazione utente + profilo (unowned) ---")

        // RC di `user` = 1
        let user = AuthenticatedUser(userID: "u-001")

        // RC di `profile` = 1 (unowned su `owner` non incrementa RC di `user`)
        let profile = UserProfile(displayName: "Alice Rossi", owner: user)
        appendLog("Profilo creato: \(profile.description())")

        // Assegnazione: `user.profile` → strong → RC di `profile` sale a 2
        user.profile = profile
        appendLog("user.profile assegnato (strong, RC profile = 2)")

        appendLog("--- Fine scope: rilascio variabili locali ---")
        // RC di `profile` scende da 2 a 1 (resta il riferimento da user.profile)
        // RC di `user`    scende da 1 a 0 → deinit di `user` chiamato
        // Durante il deinit di `user`, `user.profile` (strong) viene rilasciato:
        //   RC di `profile` scende da 1 a 0 → deinit di `profile` chiamato
        // Ordine di deallocazione: prima UserProfile, poi AuthenticatedUser
        appendLog("✅ Entrambi i deinit verranno chiamati: nessun retain cycle!")
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        log.append(message)
        print(message)
    }
}

// MARK: - View

/// Vista che illustra `unowned` e il confronto con `weak`.
struct UnownedReferenceDemo: View {

    @State private var viewModel = UnownedReferenceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox("Concetto") {
                    Text("""
                    Un riferimento **unowned** non incrementa il reference count \
                    e non è opzionale. Usalo quando sei certo che l'oggetto \
                    puntato vivrà almeno quanto l'oggetto che lo referenzia. \
                    Se l'assunzione non è rispettata, l'app crasha.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }

                Button("Dimostra unowned Reference") {
                    viewModel.demonstrateUnowned()
                }
                .buttonStyle(.borderedProminent)

                if !viewModel.log.isEmpty {
                    GroupBox("Log ARC") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.log, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(entry.hasPrefix("✅") ? .green : .primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Tabella comparativa weak vs unowned
                GroupBox("weak vs unowned — confronto") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow {
                            Text("").frame(width: 80)
                            Text("**weak**").font(.caption).bold()
                            Text("**unowned**").font(.caption).bold()
                        }
                        Divider()
                        GridRow {
                            Text("RC").font(.caption2)
                            Text("invariato").font(.caption2)
                            Text("invariato").font(.caption2)
                        }
                        GridRow {
                            Text("Tipo").font(.caption2)
                            Text("Optional").font(.caption2)
                            Text("Non-optional").font(.caption2)
                        }
                        GridRow {
                            Text("Nil se deinit").font(.caption2)
                            Text("✅ automatico").font(.caption2).foregroundStyle(.green)
                            Text("💥 crash").font(.caption2).foregroundStyle(.red)
                        }
                        GridRow {
                            Text("Usa quando").font(.caption2)
                            Text("vita incerta").font(.caption2)
                            Text("vita garantita").font(.caption2)
                        }
                    }
                    .font(.caption)
                }

                GroupBox("Riepilogo") {
                    Text("""
                    Usa `unowned` per la relazione figlio → padre quando il figlio \
                    NON può sopravvivere al padre (es. credenziali di sessione, \
                    nodi di un albero con backpointer). \
                    Preferisci `weak` se non puoi garantire l'ordine di deallocazione.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Unowned Reference")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        UnownedReferenceDemo()
    }
}
