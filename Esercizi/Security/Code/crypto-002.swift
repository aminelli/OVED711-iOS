// Scambio chiave con Curve

import CryptoKit
import Foundation

// MARK: - Key Exchange Service

actor KeyExchangeService {
    private(set) var privateKey: Curve25519.KeyAgreement.PrivateKey
    var publicKey: Curve25519.KeyAgreement.PublicKey { privateKey.publicKey }

    init() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
    }

    /// Rigenera la chiave privata (es. dopo una rotazione di sessione).
    func rotateKey() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
    }

    /// Esegue lo scambio ECDH con la chiave pubblica del peer e deriva una chiave di sessione.
    func deriveSessionKey(
        peerPublicKeyData: Data,
        salt: Data,
        info: String = "session-key-v1"
    ) throws -> SymmetricKey {
        let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data(info.utf8),
            outputByteCount: 32
        )
    }

    /// Serializza la chiave pubblica per invio al peer.
    func publicKeyData() -> Data {
        publicKey.rawRepresentation
    }
}