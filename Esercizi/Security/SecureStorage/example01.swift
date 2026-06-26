import Foundation
import Security
import CryptoKit
import LocalAuthentication

// MARK: - Errori
enum SecureStorageError: Error {
    case biometricsUnavailable
    case authenticationFailed
    case keyGenerationFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case keychainError(OSStatus)
}

// MARK: - SecureStorage
final class SecureStorage {

    // MARK: - Singleton
    static let shared = SecureStorage()

    private init() {
        try? createSecureEnclaveKeyIfNeeded()
    }

    // MARK: - Config
    private let keyTag = "com.mybank.secureenclave.key".data(using: .utf8)!
    private let aesKeyTag = "com.mybank.aes.key"
    private let dataTagPrefix = "com.mybank.data."

    // MARK: - FACE ID / TOUCH ID
    func authenticate(reason: String = "Autenticazione richiesta") async throws {

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw SecureStorageError.biometricsUnavailable
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        if !success {
            throw SecureStorageError.authenticationFailed
        }
    }

    // MARK: - 🔐 Secure Enclave Key

    private func createSecureEnclaveKeyIfNeeded() throws {

        if try getPrivateKey() != nil {
            return
        }

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            throw error!.takeRetainedValue()
        }
    }

    private func getPrivateKey() throws -> SecKey? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            return (item as! SecKey)
        }

        return nil
    }

    // MARK: - 🔑 AES Key Management

    private func generateAESKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }

    private func storeAESKey(_ key: SymmetricKey) throws {

        let keyData = key.withUnsafeBytes { Data($0) }
        let encryptedKey = try encryptWithSecureEnclave(data: keyData)

        try saveToKeychain(
            data: encryptedKey,
            account: aesKeyTag
        )
    }

    private func retrieveAESKey() throws -> SymmetricKey {

        let encryptedKeyData = try loadFromKeychain(account: aesKeyTag)

        let decryptedKeyData = try decryptWithSecureEnclave(data: encryptedKeyData)

        return SymmetricKey(data: decryptedKeyData)
    }

    private func getOrCreateAESKey() throws -> SymmetricKey {

        do {
            return try retrieveAESKey()
        } catch {
            let key = generateAESKey()
            try storeAESKey(key)
            return key
        }
    }

    // MARK: - 🔒 Encryption

    private func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!
    }

    private func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - 🔐 Secure Enclave wrapping

    private func encryptWithSecureEnclave(data: Data) throws -> Data {

        guard let privateKey = try getPrivateKey(),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureStorageError.keyNotFound
        }

        var error: Unmanaged<CFError>?

        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue()
        }

        return encrypted as Data
    }

    private func decryptWithSecureEnclave(data: Data) throws -> Data {

        guard let privateKey = try getPrivateKey() else {
            throw SecureStorageError.keyNotFound
        }

        var error: Unmanaged<CFError>?

        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            data as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue()
        }

        return decrypted as Data
    }

    // MARK: - 💾 Keychain helpers

    private func saveToKeychain(data: Data, account: String) throws {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecureStorageError.keychainError(status)
        }
    }

    private func loadFromKeychain(account: String) throws -> Data {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?

        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw SecureStorageError.keychainError(status)
        }

        return data
    }

    // MARK: - 🏦 Public API

    func save(_ value: String, for key: String) async throws {

        try await authenticate()

        let aesKey = try getOrCreateAESKey()

        guard let data = value.data(using: .utf8) else {
            throw SecureStorageError.encryptionFailed
        }

        let encrypted = try encrypt(data: data, key: aesKey)

        try saveToKeychain(
            data: encrypted,
            account: dataTagPrefix + key
        )
    }

    func load(_ key: String) async throws -> String {

        try await authenticate()

        let aesKey = try getOrCreateAESKey()

        let encrypted = try loadFromKeychain(account: dataTagPrefix + key)

        let decrypted = try decrypt(data: encrypted, key: aesKey)

        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw SecureStorageError.decryptionFailed
        }

        return string
    }

    func delete(_ key: String) {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: dataTagPrefix + key
        ]

        SecItemDelete(query as CFDictionary)
    }
}