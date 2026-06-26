
// AES-GCM

import CryptoKit
import Foundation

// MARK: - Encryption Service

actor EncryptionService {
    // MARK: - Cifratura

    /// Cifra `plaintext` con la chiave fornita; restituisce i byte combinati nonce + ciphertext + tag.
    func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoServiceError.sealFailed
        }
        return combined
    }

    /// Decifra i byte precedentemente prodotti da `encrypt(_:using:)`.
    func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Gestione chiavi

    /// Genera una nuova chiave simmetrica AES-256 (32 byte).
    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    /// Serializza una chiave in Data per archiviazione (es. Keychain).
    func keyToData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    /// Ripristina una chiave da Data.
    func keyFromData(_ data: Data) -> SymmetricKey {
        SymmetricKey(data: data)
    }

    // MARK: - Hashing

    func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - HMAC

    func hmacSHA256(message: Data, key: SymmetricKey) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(mac)
    }

    func verifyHMAC(_ mac: Data, message: Data, key: SymmetricKey) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: message, using: key)
    }
}

// MARK: - Errori

enum CryptoServiceError: Error, LocalizedError {
    case sealFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .sealFailed: return "Cifratura AES-GCM fallita: impossibile ottenere il box combinato"
        case .decryptionFailed: return "Decifratura fallita: dati corrotti o chiave errata"
        }
    }
}