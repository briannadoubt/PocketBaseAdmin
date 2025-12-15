//
//  IntentBridge.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import AppIntents
import PocketBase
import PocketBaseAdmin

#if canImport(PocketBaseIntents)
import PocketBaseIntents
#endif

/// Bridge between main app UI and App Intents
/// Provides helpers for calling intents and donating to Siri
@MainActor
public final class IntentBridge {
    public static let shared = IntentBridge()

    private init() {}

    // MARK: - Configuration Sync

    /// Syncs the current PocketBase configuration to ServerConfiguration
    /// Call this on app launch and after authentication changes
    public func syncConfiguration(from pocketbase: PocketBase) async {
        #if canImport(PocketBaseIntents)
        await ServerConfiguration.shared.syncFromPocketBase(pocketbase)
        #endif
    }

    // MARK: - Server Status

    /// Check server status using the intent
    @discardableResult
    public func checkServerStatus() async throws -> ServerStatusResult {
        #if canImport(PocketBaseIntents)
        let intent = CheckServerStatusIntent()
        let result = try await intent.perform()
        donateInteraction(intent)
        return ServerStatusResult(
            isOnline: result.value?.isOnline ?? false,
            latency: result.value?.latency,
            version: result.value?.version
        )
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    // MARK: - Backups

    /// Create a backup using the intent
    @discardableResult
    public func createBackup(name: String? = nil) async throws -> BackupResult {
        #if canImport(PocketBaseIntents)
        let intent = CreateBackupIntent(name: name)
        let result = try await intent.perform()
        donateInteraction(intent)
        return BackupResult(
            name: result.value?.name ?? "Unknown",
            size: result.value?.size ?? 0,
            created: result.value?.created ?? Date()
        )
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    /// List all backups using the intent
    @discardableResult
    public func listBackups() async throws -> [BackupResult] {
        #if canImport(PocketBaseIntents)
        let intent = ListBackupsIntent()
        let result = try await intent.perform()
        return result.value?.map { entity in
            BackupResult(
                name: entity.name,
                size: entity.size,
                created: entity.created
            )
        } ?? []
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    /// Restore a backup using the intent
    public func restoreBackup(name: String) async throws {
        #if canImport(PocketBaseIntents)
        let entity = BackupEntity(
            id: name,
            name: name,
            size: 0,
            created: Date()
        )
        let intent = RestoreBackupIntent(backup: entity)
        _ = try await intent.perform()
        // Don't donate restore - it's destructive
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    /// Delete a backup using the intent
    public func deleteBackup(name: String) async throws {
        #if canImport(PocketBaseIntents)
        let entity = BackupEntity(
            id: name,
            name: name,
            size: 0,
            created: Date()
        )
        let intent = DeleteBackupIntent(backup: entity)
        _ = try await intent.perform()
        // Don't donate delete - it's destructive
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    // MARK: - Collections

    /// Get all collections using the intent
    @discardableResult
    public func getCollections() async throws -> [CollectionResult] {
        #if canImport(PocketBaseIntents)
        let intent = GetCollectionsIntent()
        let result = try await intent.perform()
        return result.value?.map { entity in
            CollectionResult(
                id: entity.id,
                name: entity.name,
                type: entity.type.rawValue,
                recordCount: entity.recordCount
            )
        } ?? []
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    // MARK: - Logs

    /// Get recent logs using the intent
    @discardableResult
    public func getRecentLogs(limit: Int = 20) async throws -> [LogResult] {
        #if canImport(PocketBaseIntents)
        let intent = GetRecentLogsIntent()
        intent.limit = limit
        let result = try await intent.perform()
        return result.value?.map { entity in
            LogResult(
                id: entity.id,
                level: entity.level.rawValue,
                message: entity.message,
                timestamp: entity.created
            )
        } ?? []
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    /// Get error count from the last 24 hours
    @discardableResult
    public func getErrorCount() async throws -> Int {
        #if canImport(PocketBaseIntents)
        let intent = GetErrorCountIntent()
        let result = try await intent.perform()
        return result.value ?? 0
        #else
        throw IntentBridgeError.intentsNotAvailable
        #endif
    }

    // MARK: - Siri Donation

    /// Donate an intent interaction to Siri
    private func donateInteraction(_ intent: any AppIntent) {
        // Siri learns from donated interactions
        // This makes the intent more likely to appear as a suggestion
        Task {
            do {
                try await intent.donate()
            } catch {
                // Donation failures are not critical
                print("Intent donation failed: \(error)")
            }
        }
    }
}

// MARK: - Result Types

public struct ServerStatusResult: Sendable {
    public let isOnline: Bool
    public let latency: TimeInterval?
    public let version: String?
}

public struct BackupResult: Sendable {
    public let name: String
    public let size: Int64
    public let created: Date
}

public struct CollectionResult: Sendable {
    public let id: String
    public let name: String
    public let type: String
    public let recordCount: Int
}

public struct LogResult: Sendable {
    public let id: String
    public let level: Int
    public let message: String
    public let timestamp: Date
}

// MARK: - Errors

public enum IntentBridgeError: LocalizedError {
    case intentsNotAvailable

    public var errorDescription: String? {
        switch self {
        case .intentsNotAvailable:
            return "App Intents are not available on this platform"
        }
    }
}
