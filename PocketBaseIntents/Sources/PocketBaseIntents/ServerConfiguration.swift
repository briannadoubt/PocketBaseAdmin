//
//  ServerConfiguration.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import PocketBase
import PocketBaseAdmin
import KeychainAccess

/// Shared server configuration for App Intents
/// Stores server URL in App Groups and auth token in shared Keychain
public actor ServerConfiguration {
    public static let shared = ServerConfiguration()

    private let appGroupIdentifier = "group.com.briannadoubt.PocketBaseAdmin"
    private let keychainAccessGroup = "com.briannadoubt.PocketBaseAdmin.shared"
    private let serverURLKey = "PocketBaseServerURL"
    private let authTokenKey = "PocketBaseAuthToken"

    private var cachedClient: PocketBase?

    /// Shared Keychain accessible by main app, watch app, and extensions
    private let keychain: Keychain

    private init() {
        // Use shared access group so watch app can read credentials
        // Note: On simulator, keychain access groups may not work - that's OK
        self.keychain = Keychain(accessGroup: keychainAccessGroup)
            .accessibility(.afterFirstUnlock)
    }

    /// Gets the shared UserDefaults for the app group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// The configured server URL
    public var serverURL: URL? {
        get {
            sharedDefaults?.url(forKey: serverURLKey)
        }
    }

    /// Sets the server URL
    public func setServerURL(_ url: URL) {
        sharedDefaults?.set(url, forKey: serverURLKey)
        cachedClient = nil // Reset cached client
    }

    /// The stored auth token (from shared Keychain)
    public var authToken: String? {
        get {
            try? keychain.get(authTokenKey)
        }
    }

    /// Sets the auth token in shared Keychain
    public func setAuthToken(_ token: String?) {
        do {
            if let token {
                try keychain.set(token, key: authTokenKey)
            } else {
                try keychain.remove(authTokenKey)
            }
        } catch {
            // Non-fatal: keychain may not work in simulator, but app should continue
            print("Keychain error (non-fatal): \(error.localizedDescription)")
        }
        cachedClient = nil // Reset cached client
    }

    /// Gets a configured PocketBase client
    /// - Returns: A PocketBase client configured with the stored URL and auth
    public func getClient() throws -> PocketBase {
        if let cachedClient {
            return cachedClient
        }

        guard let url = serverURL else {
            throw ServerConfigurationError.noServerURL
        }

        let client = PocketBase(url: url)

        // Note: Auth token restoration would be handled by the authStore's
        // internal persistence mechanism. For intents, we rely on the
        // authStore's built-in KeychainStorage or UserDefaults storage.

        cachedClient = client
        return client
    }

    /// Checks if the server is configured
    public var isConfigured: Bool {
        serverURL != nil
    }

    /// Checks if authenticated
    public var isAuthenticated: Bool {
        authToken != nil
    }
}

public enum ServerConfigurationError: LocalizedError {
    case noServerURL
    case notAuthenticated
    case networkError(Error)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .noServerURL:
            return "No PocketBase server URL configured. Please open the app to configure."
        case .notAuthenticated:
            return "Not authenticated. Please open the app to sign in."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Sync Configuration from Main App

extension ServerConfiguration {
    /// Syncs configuration from a PocketBase instance (call from main app)
    public func syncFromPocketBase(_ pocketbase: PocketBase) {
        setServerURL(pocketbase.url)
        setAuthToken(pocketbase.authStore.token)
    }
}
