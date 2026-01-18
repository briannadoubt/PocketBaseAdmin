//
//  ConnectionHub.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Sync status for CloudKit operations
enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case error(String)
    case synced(Date)
}

/// Central hub for managing PocketBase connections
@Observable @MainActor
final class ConnectionHub {
    // MARK: - Published State

    /// All saved connections
    private(set) var connections: [Connection] = []

    /// Active PocketBase instances by connection ID
    private(set) var activeConnections: [UUID: PocketBase] = [:]

    /// Current CloudKit sync status
    private(set) var syncStatus: SyncStatus = .idle

    /// Currently selected connection ID
    var selectedConnectionID: UUID?

    // MARK: - Dependencies

    private let keychainStore: KeychainStore
    private let cloudKitSync: CloudKitSync?
    let bonjourBrowser: BonjourBrowser

    /// File URL for local connection storage
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("PocketBaseAdmin", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("connections.json")
    }

    // MARK: - Initialization

    init(
        keychainStore: KeychainStore = .shared,
        cloudKitSync: CloudKitSync? = nil,
        bonjourBrowser: BonjourBrowser = BonjourBrowser()
    ) {
        self.keychainStore = keychainStore
        self.cloudKitSync = cloudKitSync
        self.bonjourBrowser = bonjourBrowser

        loadConnections()
    }

    // MARK: - CRUD Operations

    /// Add a new connection
    func add(_ connection: Connection) async throws {
        guard !connections.contains(where: { $0.id == connection.id }) else {
            throw ConnectionHubError.duplicateConnection
        }

        var newConnection = connection

        // Sync to CloudKit if available and not a local-only connection
        if let cloudKitSync, !connection.isLocal {
            try await cloudKitSync.save(connection)
            // Persist the CloudKit record ID for future sync operations
            newConnection.cloudKitRecordID = connection.id.uuidString
        }

        connections.append(newConnection)
        saveConnections()
    }

    /// Update an existing connection
    func update(_ connection: Connection) async throws {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else {
            throw ConnectionHubError.connectionNotFound
        }

        var updatedConnection = connection

        // Sync to CloudKit if available and not a local-only connection
        if let cloudKitSync, !connection.isLocal {
            try await cloudKitSync.save(connection)
            // Ensure CloudKit record ID is persisted
            if updatedConnection.cloudKitRecordID == nil {
                updatedConnection.cloudKitRecordID = connection.id.uuidString
            }
        }

        connections[index] = updatedConnection
        saveConnections()
    }

    /// Remove a connection
    func remove(_ connection: Connection) async throws {
        // Disconnect if active
        disconnect(from: connection)

        // Remove credentials
        try? keychainStore.deleteToken(for: connection.id)

        // Remove from list
        connections.removeAll { $0.id == connection.id }
        saveConnections()

        // Remove from CloudKit if available (use connection.id as fallback for record ID)
        if let cloudKitSync, !connection.isLocal {
            let recordID = connection.cloudKitRecordID ?? connection.id.uuidString
            try await cloudKitSync.delete(recordID: recordID)
        }
    }

    // MARK: - Connection Lifecycle

    /// Connect to a PocketBase instance
    @discardableResult
    func connect(to connection: Connection) async throws -> PocketBase {
        // Return existing connection if available
        if let existing = activeConnections[connection.id] {
            return existing
        }

        // Create new PocketBase instance
        let pb = PocketBase(url: connection.url)

        // Store the active connection
        activeConnections[connection.id] = pb

        // Update last connected timestamp
        var updatedConnection = connection
        updatedConnection.lastConnected = Date()
        try? await update(updatedConnection)

        return pb
    }

    /// Disconnect from a PocketBase instance
    func disconnect(from connection: Connection) {
        activeConnections.removeValue(forKey: connection.id)
    }

    /// Get the PocketBase instance for a connection if connected
    func pocketbase(for connection: Connection) -> PocketBase? {
        activeConnections[connection.id]
    }

    /// Get the PocketBase instance for a connection ID if connected
    func pocketbase(for connectionID: UUID) -> PocketBase? {
        activeConnections[connectionID]
    }

    // MARK: - Authentication

    /// Authenticate with a connection using the Superuser collection
    func authenticate(
        connection: Connection,
        email: String,
        password: String
    ) async throws {
        let pb = try await connect(to: connection)

        // Authenticate with PocketBase using the Superuser collection
        let collection = pb.collection(Superuser.self)
        _ = try await collection.authWithPassword(email, password: password)

        // Save email to keychain for reference (token is managed by PocketBase authStore)
        if let token = pb.authStore.token {
            try keychainStore.saveToken(token, for: connection.id, email: email)
        }
    }

    /// Check if a connection is authenticated
    func isAuthenticated(for connection: Connection) -> Bool {
        guard let pb = activeConnections[connection.id] else {
            return keychainStore.hasCredentials(for: connection.id)
        }
        return pb.authStore.isValid
    }

    /// Logout from a connection
    func logout(from connection: Connection) throws {
        if let pb = activeConnections[connection.id] {
            pb.authStore.clear()
        }
        try keychainStore.deleteToken(for: connection.id)
    }

    // MARK: - CloudKit Sync

    /// Sync connections with CloudKit
    func syncWithCloudKit() async throws {
        guard let cloudKitSync else { return }

        syncStatus = .syncing

        do {
            let remoteConnections = try await cloudKitSync.fetchAll()

            // Merge remote connections with local
            for remote in remoteConnections {
                if let index = connections.firstIndex(where: { $0.cloudKitRecordID == remote.cloudKitRecordID }) {
                    // Update existing if remote is newer
                    if let remoteDate = remote.lastConnected,
                       let localDate = connections[index].lastConnected,
                       remoteDate > localDate {
                        connections[index] = remote
                    }
                } else if !remote.isLocal {
                    // Add new remote connection
                    connections.append(remote)
                }
            }

            saveConnections()
            syncStatus = .synced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Bonjour Discovery

    /// Discovered instances on the local network
    var discoveredInstances: [BonjourBrowser.DiscoveredInstance] {
        bonjourBrowser.discoveredInstances
    }

    /// Start browsing for PocketBase instances on the network
    func startBonjourBrowsing() {
        bonjourBrowser.startBrowsing()
    }

    /// Stop browsing for PocketBase instances
    func stopBonjourBrowsing() {
        bonjourBrowser.stopBrowsing()
    }

    /// Add a discovered instance as a connection
    func addDiscoveredInstance(_ instance: BonjourBrowser.DiscoveredInstance) async throws {
        let connection = Connection(
            name: instance.name,
            host: instance.host,
            port: instance.port,
            useTLS: false,
            discoveredViaBonjour: true
        )
        try await add(connection)
    }

    // MARK: - Local Storage

    private func loadConnections() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            #if os(macOS)
            // Add default localhost connection on first launch (macOS only)
            connections = [.localhost()]
            saveConnections()
            #else
            // On iOS/visionOS, start with empty list and rely on Bonjour discovery
            connections = []
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            connections = try JSONDecoder().decode([Connection].self, from: data)
        } catch {
            print("Failed to load connections: \(error)")
            #if os(macOS)
            connections = [.localhost()]
            #else
            connections = []
            #endif
        }
    }

    private func saveConnections() {
        do {
            let data = try JSONEncoder().encode(connections)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }
}

// MARK: - Errors

enum ConnectionHubError: LocalizedError {
    case duplicateConnection
    case connectionNotFound
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .duplicateConnection:
            return "A connection with this ID already exists"
        case .connectionNotFound:
            return "Connection not found"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        }
    }
}

// MARK: - Environment Key

private struct ConnectionHubKey: EnvironmentKey {
    static let defaultValue: ConnectionHub? = nil
}

extension EnvironmentValues {
    var connectionHub: ConnectionHub? {
        get { self[ConnectionHubKey.self] }
        set { self[ConnectionHubKey.self] = newValue }
    }
}
