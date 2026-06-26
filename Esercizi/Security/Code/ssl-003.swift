// Backservice snapshot test per protection con swiftui

import SwiftUI

// MARK: - Background Snapshot Overlay

struct BackgroundSnapshotProtectedApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if scenePhase == .inactive || scenePhase == .background {
                        PrivacyOverlayView()
                            .ignoresSafeArea()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Operazioni aggiuntive di sicurezza (es. lock memorie sensibili)
            }
        }
    }
}

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Contenuto protetto")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Struttura app principale con anti-debug

@main
struct SecureApp: App {
    init() {
        applyAntiDebugMeasures()
        Task {
            await applyJailbreakCheck()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private func applyAntiDebugMeasures() {
        #if !DEBUG
        // Nega attach debugger tramite dlopen/dlsym
        // (ptrace non è direttamente linkabile su iOS SDK pubblico)
        if let handle = dlopen(nil, RTLD_GLOBAL | RTLD_NOW) {
            typealias PTraceFn = @convention(c) (CInt, pid_t, caddr_t?, CInt) -> CInt
            if let sym = dlsym(handle, "ptrace") {
                let ptraceFunc = unsafeBitCast(sym, to: PTraceFn.self)
                _ = ptraceFunc(31 /* PT_DENY_ATTACH */, 0, nil, 0)
            }
        }
        #endif
    }

    private func applyJailbreakCheck() async {
        #if !targetEnvironment(simulator)
        let detector = JailbreakDetector()
        let result = await detector.detect()
        if result.isJailbroken {
            // In produzione: log evento sicurezza, blocca accesso, disconnetti utente
            await MainActor.run {
                // Mostrare alert o terminare
            }
        }
        #endif
    }
}