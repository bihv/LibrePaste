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
    public nonisolated static let shared = CryptoService()
    
    private let serviceName = "bihv.LibrePaste.encryption"
    private let accountName = "DatabaseMasterKey"
    
    private nonisolated(unsafe) var cachedKey: SymmetricKey?
    private let lock = NSLock()
    
    private init() {
        self.cachedKey = loadOrGenerateMasterKey()
    }
    
    // MARK: - Key Management
    
    private nonisolated var keyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = appSupport.appendingPathComponent("LibrePaste", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".master_encryption.key")
    }
    
    private nonisolated func loadKeyFromFile() -> SymmetricKey? {
        guard let data = try? Data(contentsOf: keyFileURL), data.count == 32 else {
            return nil
        }
        return SymmetricKey(data: data)
    }
    
    private nonisolated func saveKeyToFile(_ key: SymmetricKey) {
        let data = key.withUnsafeBytes { Data($0) }
        let path = keyFileURL.path
        try? data.write(to: keyFileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }
    
    /// Loads master key from secure file storage / macOS Keychain, or generates and securely saves a new one.
    private nonisolated func loadOrGenerateMasterKey() -> SymmetricKey {
        // 1. Try file-based secure storage first (fast, atomic, zero prompts, POSIX 0600)
        if let fileKey = loadKeyFromFile() {
            return fileKey
        }
        
        // 2. Try macOS Keychain
        if let keychainKey = loadKeyFromKeychain() {
            saveKeyToFile(keychainKey)
            return keychainKey
        }
        
        // 3. Generate a new 256-bit symmetric key and persist securely
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToFile(newKey)
        saveKeyToKeychain(newKey)
        return newKey
    }
    
    private nonisolated func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        
        return nil
    }
    
    private nonisolated func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: keyData
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let baseQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: accountName,
                kSecUseDataProtectionKeychain as String: true
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            _ = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        }
    }
    
    private nonisolated var masterKey: SymmetricKey {
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
    public nonisolated func encrypt(data: Data) -> Data? {
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
    public nonisolated func decrypt(data: Data) -> Data? {
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
    public nonisolated func encryptString(_ text: String) -> Data? {
        guard let data = text.data(using: .utf8) else { return nil }
        return encrypt(data: data)
    }
    
    /// Decrypts AES-GCM Data into a UTF-8 String.
    public nonisolated func decryptString(from data: Data) -> String? {
        guard let decryptedData = decrypt(data: data) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
}
