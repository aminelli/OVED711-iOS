// Firma digitale con P256

import CryptoKit
import Foundation

// MARK: - Signing Service

actor SigningService {
    private let privateKey: P256.Signing.PrivateKey

    init() {
        privateKey = P256.Signing.PrivateKey()
    }

    /// Chiave pubblica da condividere con il verificatore.
    var publicKeyData: Data { privateKey.publicKey.compressedRepresentation }

    /// Firma i dati; restituisce la firma DER-encoded.
    func sign(_ data: Data) throws -> Data {
        let signature = try privateKey.signature(for: data)
        return signature.derRepresentation
    }

    /// Verifica la firma usando la chiave pubblica serializzata.
    func verify(
        signature derSignature: Data,
        for data: Data,
        publicKeyData: Data
    ) throws -> Bool {
        let publicKey = try P256.Signing.PublicKey(compressedRepresentation: publicKeyData)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: derSignature)
        return publicKey.isValidSignature(signature, for: data)
    }
}

// MARK: - ViewModel di esempio

@Observable @MainActor
final class CryptoViewModel {
    var encryptedHex: String = ""
    var decryptedText: String = ""
    var signatureValid: Bool?
    var errorMessage: String?

    private let encService = EncryptionService()
    private let sigService = SigningService()

    func runDemo() async {
        do {
            // 1. Genera chiave e cifra
            let key = await encService.generateKey()
            let plaintext = Data("Messaggio segreto!".utf8)
            let encrypted = try await encService.encrypt(plaintext, using: key)
            encryptedHex = encrypted.map { String(format: "%02x", $0) }.joined()

            // 2. Decifra
            let decrypted = try await encService.decrypt(encrypted, using: key)
            decryptedText = String(data: decrypted, encoding: .utf8) ?? ""

            // 3. Firma e verifica
            let payload = Data("payload da firmare".utf8)
            let sig = try await sigService.sign(payload)
            let pubKey = await sigService.publicKeyData
            signatureValid = try await sigService.verify(signature: sig, for: payload, publicKeyData: pubKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}