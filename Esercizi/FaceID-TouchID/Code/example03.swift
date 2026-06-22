// ViewModel con gestione LAError

import SwiftUI
import LocalAuthentication

// MARK: - Auth ViewModel

@Observable @MainActor
final class AuthViewModel {
    var isAuthenticated = false
    var errorMessage: String?
    var biometryName: String = "Biometria"

    private let authService = BiometricAuthService()
    private let keychainService = KeychainBiometricService()

    func setup() async {
        let type = await authService.biometryType
        switch type {
        case .faceID: biometryName = "Face ID"
        case .touchID: biometryName = "Touch ID"
        default: biometryName = "Passcode"
        }
    }

    func login() async {
        do {
            try await authService.authenticate(reason: "Accedi al tuo account")
            isAuthenticated = true
        } catch let err as BiometricError {
            switch err {
            case .lockout:
                errorMessage = err.localizedDescription
            case .notEnrolled:
                // Guida l'utente alle Impostazioni
                errorMessage = "Abilita Face ID/Touch ID nelle Impostazioni per continuare"
            default:
                errorMessage = err.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct BiometricLoginView: View {
    @State private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Accedi con \(viewModel.biometryName)")
                .font(.title2)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Autentica") {
                Task { await viewModel.login() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { await viewModel.setup() }
    }
}