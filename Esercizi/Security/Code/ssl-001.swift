// Pinning utl session con ceretificate e chiave pubblica

import Foundation
import CryptoKit
import Security

// MARK: - Configurazione pinning

struct TLSPinningConfig: Sendable {
    /// Certificati DER-encoded salvati nell'app bundle (certificate pinning)
    let pinnedCertificates: [Data]
    /// Hash SHA-256 della chiave pubblica del server (public key pinning)
    let pinnedPublicKeyHashes: Set<String>

    static func load(certificateNames: [String]) -> TLSPinningConfig {
        let certs = certificateNames.compactMap { name -> Data? in
            guard let url = Bundle.main.url(forResource: name, withExtension: "cer"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return data
        }
        return TLSPinningConfig(pinnedCertificates: certs, pinnedPublicKeyHashes: [])
    }
}

// MARK: - URLSessionDelegate con pinning

final class PinningURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let config: TLSPinningConfig

    init(config: TLSPinningConfig) {
        self.config = config
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Certificate pinning
        if !config.pinnedCertificates.isEmpty {
            if verifyCertificatePinning(serverTrust: serverTrust) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        // Public key pinning
        if !config.pinnedPublicKeyHashes.isEmpty {
            if verifyPublicKeyPinning(serverTrust: serverTrust) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - Certificate pinning

    private func verifyCertificatePinning(serverTrust: SecTrust) -> Bool {
        let certCount = SecTrustGetCertificateCount(serverTrust)
        for i in 0..<certCount {
            guard let cert = SecTrustGetCertificateAtIndex(serverTrust, i) else { continue }
            let certData = SecCertificateCopyData(cert) as Data
            if config.pinnedCertificates.contains(certData) { return true }
        }
        return false
    }

    // MARK: - Public key pinning

    private func verifyPublicKeyPinning(serverTrust: SecTrust) -> Bool {
        guard let leafCert = SecTrustGetCertificateAtIndex(serverTrust, 0),
              let publicKey = SecCertificateCopyKey(leafCert) else { return false }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else { return false }

        // Header SPKI per P-256 (da aggiungere prima del raw key per ottenere SPKI standard)
        let spkiHeader = Data([
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
            0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
            0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
            0x42, 0x00
        ])
        let spkiData = spkiHeader + keyData
        let hash = SHA256.hash(data: spkiData)
        let hashBase64 = Data(hash).base64EncodedString()
        return config.pinnedPublicKeyHashes.contains(hashBase64)
    }
}

// MARK: - Networking actor che usa pinning

actor PinnedNetworkService {
    private let session: URLSession

    init(config: TLSPinningConfig) {
        let delegate = PinningURLSessionDelegate(config: config)
        session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func fetch(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NetworkError.invalidResponse
        }
        return data
    }
}

enum NetworkError: Error { case invalidResponse }
