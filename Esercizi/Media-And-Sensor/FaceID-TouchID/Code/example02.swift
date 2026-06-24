// Keychain Biometric Service

import Security
import Foundation

// MARK: - Keychain Biometric Service

actor KeychainBiometricService {
    private let service = "com.app.securetoken"
    private let account = "user-jwt"

    // MARK: - Scrittura (al login)

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { throw KeychainError.encodingFailed }

        // Crea access control: biometria corrente richiesta per lettura
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.accessControlFailed(error?.takeRetainedValue().localizedDescription ?? "")
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessControl: access
        ]

        // Rimuove eventuale entry precedente
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    // MARK: - Lettura (richiede autenticazione biometrica)

    func loadToken(reason: String) async throws -> String {
        let context = LAContext()
        context.localizedReason = reason

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.loadFailed(status)
        }
        return token
    }

    // MARK: - Eliminazione

    func deleteToken() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Errori Keychain

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case accessControlFailed(String)
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Codifica del token fallita"
        case .accessControlFailed(let msg): return "Access control: \(msg)"
        case .saveFailed(let s): return "Salvataggio Keychain fallito (OSStatus \(s))"
        case .loadFailed(let s): return "Lettura Keychain fallita (OSStatus \(s))"
        case .deleteFailed(let s): return "Eliminazione Keychain fallita (OSStatus \(s))"
        }
    }
}