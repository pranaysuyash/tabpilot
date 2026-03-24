import Foundation
import Security

enum SecureEnclaveKeyManagerError: Error {
    case keyGenerationFailed
    case signFailed
}

enum KeyProtectionMode: String {
    case secureEnclave
    case software
    case unknown
}

enum SecureEnclaveKeyManager {
    private static let keyTag = "com.pranay.chrometabmanager.security.audit.signingkey".data(using: .utf8)!

    static func isSecureEnclaveAvailable() -> Bool {
        keyProtectionMode() == .secureEnclave
    }

    static func keyProtectionMode() -> KeyProtectionMode {
        guard let key = getStoredKey() else {
            return .unknown
        }
        return keyHasSecureEnclaveToken(key) ? .secureEnclave : .software
    }

    static func sign(_ payload: Data) throws -> Data {
        let privateKey = try ensurePrivateKey()
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? SecureEnclaveKeyManagerError.signFailed
        }
        return signature
    }

    static func ensurePrivateKey() throws -> SecKey {
        if let existing = getStoredKey() {
            return existing
        }

        if let generatedSecureEnclave = try createSecureEnclaveKey() {
            return generatedSecureEnclave
        }

        return try createFallbackSoftwareKey()
    }

    private static func createSecureEnclaveKey() throws -> SecKey? {
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) else {
            return nil
        }

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
        let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        if key == nil {
            return nil
        }
        return key
    }

    private static func createFallbackSoftwareKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let cfError = error?.takeRetainedValue() {
                throw cfError
            }
            throw SecureEnclaveKeyManagerError.keyGenerationFailed
        }
        return key
    }

    private static func getStoredKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return (item as! SecKey)
    }

    private static func keyHasSecureEnclaveToken(_ key: SecKey) -> Bool {
        guard
            let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
            let token = attributes[kSecAttrTokenID] as? String
        else {
            return false
        }

        return token == (kSecAttrTokenIDSecureEnclave as String)
    }
}
