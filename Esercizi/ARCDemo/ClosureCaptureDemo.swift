//
//  ClosureCaptureDemo.swift
//  ARCDemo
//
//  Scenario 4: retain cycle nelle closure e capture list.
//  Una closure è un reference type: quando cattura `self` implicitamente,
//  incrementa il reference count di `self`. Se `self` detiene anche la closure,
//  si forma un retain cycle. La soluzione è una capture list con [weak self]
//  o [unowned self].
//

import SwiftUI

// MARK: - Modello

/// Timer simulato che esegue una closure periodicamente.
/// Tiene in memoria la closure con un riferimento forte.
final class RepeatingTimer {

    /// Intervallo di esecuzione (usato solo a scopo descrittivo nel demo).
    let interval: TimeInterval

    /// La closure viene mantenuta con riferimento forte da questo oggetto.
    /// Se la closure cattura `self` (il proprietario del timer) con strong,
    /// si crea un retain cycle: Timer → closure → self → Timer.
    var action: (() -> Void)?

    init(interval: TimeInterval) {
        self.interval = interval
        print("✅ RepeatingTimer allocato (interval: \(interval)s)")
    }

    deinit {
        print("♻️ RepeatingTimer deallocato")
    }

    /// Simula un singolo tick del timer.
    func fire() {
        action?()
    }
}

// MARK: - Controller con retain cycle

/// Controller che crea un retain cycle tramite closure.
/// Possiede un timer E viene catturato dalla closure del timer → ciclo.
final class LeakyController {

    let name: String
    /// Il timer è posseduto dal controller (strong)
    var timer: RepeatingTimer?
    /// Contatore degli eventi ricevuti
    private(set) var eventCount = 0

    init(name: String) {
        self.name = name
        print("✅ LeakyController '\(name)' allocato")
        setupTimer()
    }

    private func setupTimer() {
        timer = RepeatingTimer(interval: 1.0)
        // ⚠️ RETAIN CYCLE: la closure cattura `self` implicitamente con strong.
        // LeakyController → timer (strong) → action (strong) → self (strong) → cycle!
        timer?.action = {
            // `self` qui è catturato con forte riferimento
            self.eventCount += 1
            print("LeakyController '\(self.name)' evento #\(self.eventCount)")
        }
    }

    deinit {
        print("♻️ LeakyController '\(name)' deallocato")
    }
}

// MARK: - Controller senza retain cycle (weak self)

/// Controller che usa `[weak self]` nella capture list per evitare il retain cycle.
final class SafeWeakController {

    let name: String
    var timer: RepeatingTimer?
    private(set) var eventCount = 0

    init(name: String) {
        self.name = name
        print("✅ SafeWeakController '\(name)' allocato")
        setupTimer()
    }

    private func setupTimer() {
        timer = RepeatingTimer(interval: 1.0)
        // ✅ [weak self]: se `self` viene deallocato, il riferimento diventa nil.
        // È necessario fare l'unwrap con `guard let self` o `self?`.
        // Sintassi moderna Swift 6: `[weak self]` + `guard let self`
        timer?.action = { [weak self] in
            // `self` è ora Optional: ARC non tiene in vita il controller per questa closure
            guard let self else { return }
            self.eventCount += 1
            print("SafeWeakController '\(self.name)' evento #\(self.eventCount)")
        }
    }

    deinit {
        print("♻️ SafeWeakController '\(name)' deallocato")
    }
}

// MARK: - Controller senza retain cycle (unowned self)

/// Controller che usa `[unowned self]` quando la closure non sopravviverà al controller.
/// Se il controller venisse deallocato prima della closure, l'app crasherebbe:
/// usare `unowned` solo quando si è certi dell'ordine di deallocazione.
final class SafeUnownedController {

    let name: String
    var timer: RepeatingTimer?
    private(set) var eventCount = 0

    init(name: String) {
        self.name = name
        print("✅ SafeUnownedController '\(name)' allocato")
        setupTimer()
    }

    private func setupTimer() {
        timer = RepeatingTimer(interval: 1.0)
        // ✅ [unowned self]: nessun Optional, accesso diretto.
        // Sicuro perché il timer (e la sua closure) viene deallocato prima del controller
        // (il controller è il proprietario del timer).
        timer?.action = { [unowned self] in
            // Accesso diretto senza unwrap: il controller è garantito in vita
            self.eventCount += 1
            print("SafeUnownedController '\(self.name)' evento #\(self.eventCount)")
        }
    }

    deinit {
        print("♻️ SafeUnownedController '\(name)' deallocato")
    }
}

// MARK: - ViewModel

/// ViewModel che gestisce i tre scenari di capture nelle closure.
@Observable
final class ClosureCaptureViewModel {

    var log: [String] = []

    /// Dimostra il retain cycle: il controller NON verrà deallocato.
    func demonstrateRetainCycle() {
        log.removeAll()
        appendLog("--- Scenario: [strong self] implicito → RETAIN CYCLE ---")
        do {
            let controller = LeakyController(name: "Leaky")
            controller.timer?.fire()
            appendLog("Timer fired. Uscita scope...")
            // ⚠️ deinit NON verrà chiamato: retain cycle attivo
        }
        appendLog("⚠️ deinit NON chiamato: memory leak!")
    }

    /// Dimostra la soluzione con `[weak self]`.
    func demonstrateWeakCapture() {
        log.removeAll()
        appendLog("--- Scenario: [weak self] → nessun retain cycle ---")
        do {
            let controller = SafeWeakController(name: "SafeWeak")
            controller.timer?.fire()
            appendLog("Timer fired. Uscita scope...")
            // ✅ deinit verrà chiamato: weak non trattiene self
        }
        appendLog("✅ deinit chiamato: nessun memory leak!")
    }

    /// Dimostra la soluzione con `[unowned self]`.
    func demonstrateUnownedCapture() {
        log.removeAll()
        appendLog("--- Scenario: [unowned self] → nessun retain cycle ---")
        do {
            let controller = SafeUnownedController(name: "SafeUnowned")
            controller.timer?.fire()
            appendLog("Timer fired. Uscita scope...")
            // ✅ deinit verrà chiamato: unowned non trattiene self
        }
        appendLog("✅ deinit chiamato: nessun memory leak!")
    }

    private func appendLog(_ message: String) {
        log.append(message)
        print(message)
    }
}

// MARK: - View

/// Vista che illustra i tre pattern di capture nelle closure.
struct ClosureCaptureDemo: View {

    @State private var viewModel = ClosureCaptureViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox("Concetto") {
                    Text("""
                    Le closure catturano i valori del contesto in cui sono definite. \
                    Se una closure cattura `self` implicitamente (strong) e `self` \
                    detiene la closure, si crea un retain cycle. \
                    La **capture list** `[weak self]` o `[unowned self]` interrompe il ciclo.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }

                // Scenario 1: retain cycle
                GroupBox("1. Retain cycle (strong implicito)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("La closure cattura `self` implicitamente → memory leak.")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button("Simula retain cycle") {
                            viewModel.demonstrateRetainCycle()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                // Scenario 2: weak self
                GroupBox("2. Soluzione con [weak self]") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("`self` è Optional nella closure → safe, richiede unwrap.")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Button("Simula [weak self]") {
                            viewModel.demonstrateWeakCapture()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }

                // Scenario 3: unowned self
                GroupBox("3. Soluzione con [unowned self]") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("`self` non è Optional → no unwrap, ma rischio crash se vita non garantita.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Simula [unowned self]") {
                            viewModel.demonstrateUnownedCapture()
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }

                // Log
                if !viewModel.log.isEmpty {
                    GroupBox("Log ARC") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.log, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(
                                        entry.hasPrefix("✅") ? .green :
                                        entry.hasPrefix("⚠️") ? .red : .primary
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Riepilogo") {
                    Text("""
                    Usa `[weak self]` nelle closure che possono sopravvivere a `self` \
                    (timer, callback di rete, notifiche). \
                    Usa `[unowned self]` quando la closure è strettamente legata \
                    alla vita di `self` e ne sei certo (es. animazioni, lazy init). \
                    Con Swift 6 la sintassi `guard let self` è la più leggibile.
                    """)
                    .font(.footnote)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Closure Capture")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ClosureCaptureDemo()
    }
}
