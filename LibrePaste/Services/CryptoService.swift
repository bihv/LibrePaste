//
//  CryptoService.swift
//  LibrePaste
//
//  Created by LibrePaste Team.
//

import Foundation
import CryptoKit
import Security

/// Thread-safe cryptographic service utilizing Apple CryptoKit (AES-GCM 256-bit)
/// with master keys stored securely in the macOS Keychain.
public final class CryptoService: @unchecked Sendable {
    public static let shared = CryptoService()
    
    private let serviceName = "bihv.LibrePaste.encryption"
    private let accountName = "DatabaseMasterKey"
    
    private var cachedKey: SymmetricKey?
    private let lock = NSLock()
    
    private init() {
        self.cachedKey = loadOrGenerateMasterKey()
    }
    
    // MARK: - Key Management
    
    /// Loads master key from macOS Keychain, or generates and securely saves a new one.
    private func loadOrGenerateMasterKey() -> SymmetricKey {
        if let existingKey = loadKeyFromKeychain() {
            return existingKey
        }
        
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToKeychain(newKey)
        return newKey
    }
    
    private func loadKeyFromKeychain() -> SymmetricKey? {
        // 1. Try standard query (persists reliably across debug rebuilds and launches)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        
        // 2. Fallback to Data Protection query if standard query did not find it
        if status != errSecSuccess {
            query[kSecUseDataProtectionKeychain as String] = true
            item = nil
            status = SecItemCopyMatching(query as CFDictionary, &item)
        }
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        return SymmetricKey(data: data)
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: accountName
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        }
        
        if status != errSecSuccess {
            print("[CryptoService] Keychain save failed with OSStatus: \(status)")
        }
    }
    
    private var masterKey: SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        
        if let key = cachedKey {
            return key
        }
        let key = loadOrGenerateMasterKey()
        cachedKey = key
        return key
    }
    
    // MARK: - Encryption & Decryption (Data)
    
    /// Encrypts raw data using AES-GCM (Nonce + Ciphertext + Authentication Tag).
    public func encrypt(data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        do {
            let sealedBox = try AES.GCM.seal(data, using: masterKey)
            return sealedBox.combined
        } catch {
            print("[CryptoService] Encryption failed: \(error)")
            return nil
        }
    }
    
    /// Decrypts AES-GCM data. If decryption fails, returns nil.
    public func decrypt(data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: masterKey)
        } catch {
            return nil
        }
    }
    
    // MARK: - Encryption & Decryption (String)
    
    /// Encrypts a string into AES-GCM encrypted Data.
    public func encryptString(_ text: String) -> Data? {
        guard let data = text.data(using: .utf8) else { return nil }
        return encrypt(data: data)
    }
    
    /// Decrypts AES-GCM Data into a UTF-8 String.
    public func decryptString(from data: Data) -> String? {
        guard let decryptedData = decrypt(data: data) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
}
