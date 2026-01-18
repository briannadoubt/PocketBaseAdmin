//
//  KeychainStore.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import Security

/// Stores authentication credentials in the system keychain with iCloud sync support
final class KeychainStore: Sendable {
    /// Service name for keychain items
    private let service = "com.briannadoubt.PocketBaseAdmin"

    /// Access group for sharing across app extensions
    private let accessGroup = "com.briannadoubt.PocketBaseAdmin.shared"

    /// Shared instance
    static let shared = KeychainStore()

    private init() {}

    // MARK: - Credential Operations

    /// Save authentication token for a connection
    func saveToken(_ token: String, for connectionID: UUID, email: String) throws {
        let credential = KeychainCredential(connectionID: connectionID, email: email, token: token)
        try save(credential)
    }

    /// Load authentication token for a connection
    func loadToken(for connectionID: UUID) throws -> KeychainCredential? {
        try load(for: connectionID)
    }

    /// Delete authentication token for a connection
    func deleteToken(for connectionID: UUID) throws {
        try delete(for: connectionID)
    }

    /// Check if credentials exist for a connection
    func hasCredentials(for connectionID: UUID) -> Bool {
        (try? load(for: connectionID)) != nil
    }

    // MARK: - Private Implementation

    private func save(_ credential: KeychainCredential) throws {
        // First try to delete any existing item
        try? delete(for: credential.connectionID)

        let data = try JSONEncoder().encode(credential)

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: credential.connectionID.uuidString,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            // Enable iCloud Keychain sync
            kSecAttrSynchronizable: kCFBooleanTrue as Any
        ]

        // Add access group for app extensions
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup] = accessGroup
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func load(for connectionID: UUID) throws -> KeychainCredential? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: connectionID.uuidString,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup] = accessGroup
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return try JSONDecoder().decode(KeychainCredential.self, from: data)
    }

    private func delete(for connectionID: UUID) throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: connectionID.uuidString,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup] = accessGroup
        #endif

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Delete all stored credentials
    func deleteAll() throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
        ]

        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup] = accessGroup
        #endif

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Supporting Types

/// Credential stored in keychain
struct KeychainCredential: Codable, Sendable {
    /// Connection this credential belongs to
    let connectionID: UUID

    /// Admin email address
    var email: String

    /// Authentication token (NOT the raw password)
    var token: String
}

/// Keychain operation errors
enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .invalidData:
            return "Invalid data in keychain"
        }
    }
}
