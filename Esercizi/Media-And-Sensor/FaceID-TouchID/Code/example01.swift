

import LocalAuthentication
import Foundation

// MARK: - Biometric Auth Service

actor BiometricAuthService {
    // MARK: - Verifica disponibilità

    var biometryType: LABiometryType {
        let ctx = LAContext()
        var error: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return ctx.biometryType
    }

    func isAvailable() -> Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // MARK: - Autenticazione biometrica

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Usa passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // biometria + fallback passcode
                localizedReason: reason
            )
            guard success else { throw BiometricError.authFailed }
        } catch let laError as LAError {
            throw BiometricError.from(laError)
        }
    }

    // MARK: - Invalidazione

    func invalidate(_ context: LAContext) {
        context.invalidate()
    }
}

// MARK: - Errori biometrici

enum BiometricError: Error, LocalizedError {
    case authFailed
    case userCancelled
    case userFallback
    case lockout
    case notEnrolled
    case notAvailable
    case systemError(String)

    static func from(_ error: LAError) -> BiometricError {
        switch error.code {
        case .authenticationFailed: return .authFailed
        case .userCancel: return .userCancelled
        case .userFallback: return .userFallback
        case .biometryLockout: return .lockout
        case .biometryNotEnrolled: return .notEnrolled
        case .biometryNotAvailable: return .notAvailable
        default: return .systemError(error.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .authFailed: return "Autenticazione fallita"
        case .userCancelled: return "Autenticazione annullata dall'utente"
        case .userFallback: return "L'utente ha scelto il passcode"
        case .lockout: return "Biometria bloccata: troppi tentativi. Sblocca con il passcode"
        case .notEnrolled: return "Nessuna biometria configurata nelle Impostazioni"
        case .notAvailable: return "Biometria non disponibile su questo dispositivo"
        case .systemError(let msg): return "Errore di sistema: \(msg)"
        }
    }
}