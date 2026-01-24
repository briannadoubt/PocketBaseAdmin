//
//  IntentHelpers.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import AppIntents

/// Helper functions to call intents and return simplified types for widgets and Watch app
public enum IntentHelpers {

    // MARK: - Server Status

    /// Fetch the current server status
    @MainActor
    public static func fetchServerStatus() async -> SimpleServerStatus {
        do {
            let intent = CheckServerStatusIntent()
            let result = try await intent.perform()
            // The value is optional, unwrap it
            if let entity = result.value {
                return SimpleServerStatus(from: entity)
            }
            return .offline
        } catch {
            return .offline
        }
    }

    // MARK: - Collections

    /// Fetch all collections
    @MainActor
    public static func fetchCollections(includeSystem: Bool = false) async -> [SimpleCollection] {
        do {
            let intent = GetCollectionsIntent(includeSystem: includeSystem)
            let result = try await intent.perform()
            if let entities = result.value {
                return entities.map { SimpleCollection(from: $0) }
            }
            return []
        } catch {
            return []
        }
    }

    // MARK: - Logs

    /// Fetch recent log entries
    @MainActor
    public static func fetchRecentLogs(limit: Int = 10, level: LogLevelFilter = .all) async -> [SimpleLogEntry] {
        do {
            let intent = GetRecentLogsIntent(level: level, limit: limit)
            let result = try await intent.perform()
            if let entities = result.value {
                return entities.map { SimpleLogEntry(from: $0) }
            }
            return []
        } catch {
            return []
        }
    }

    /// Fetch the count of errors in the last 24 hours
    @MainActor
    public static func fetchErrorCount() async -> Int {
        do {
            let intent = GetErrorCountIntent()
            let result = try await intent.perform()
            return result.value ?? 0
        } catch {
            return 0
        }
    }

    /// Fetch the count of warnings in the last 24 hours
    @MainActor
    public static func fetchWarningCount() async -> Int {
        let logs = await fetchRecentLogs(limit: 100, level: .warning)
        return logs.filter { $0.level == .warning }.count
    }

    // MARK: - Backups

    /// Fetch all backups
    @MainActor
    public static func fetchBackups() async -> [SimpleBackup] {
        do {
            let intent = ListBackupsIntent()
            let result = try await intent.perform()
            if let entities = result.value {
                return entities.map { SimpleBackup(from: $0) }
            }
            return []
        } catch {
            return []
        }
    }

    /// Create a new backup
    @MainActor
    public static func createBackup(name: String? = nil) async throws -> SimpleBackup {
        let intent = CreateBackupIntent(name: name)
        let result = try await intent.perform()
        guard let entity = result.value else {
            throw IntentHelpersError.noValueReturned
        }
        return SimpleBackup(from: entity)
    }

    // MARK: - Errors

    public enum IntentHelpersError: Error {
        case noValueReturned
    }

    // MARK: - Combined Stats

    /// A combined stats result for widgets that need multiple data points
    public struct StatsResult: Sendable {
        public let serverStatus: SimpleServerStatus
        public let collections: [SimpleCollection]
        public let errorCount: Int
        public let warningCount: Int

        public var collectionsCount: Int { collections.count }
        public var totalRecords: Int { collections.reduce(0) { $0 + $1.recordCount } }
    }

    /// Fetch combined stats for dashboard widgets
    @MainActor
    public static func fetchStats() async -> StatsResult {
        async let status = fetchServerStatus()
        async let collections = fetchCollections()
        async let errorCount = fetchErrorCount()
        async let warningCount = fetchWarningCount()

        return await StatsResult(
            serverStatus: status,
            collections: collections,
            errorCount: errorCount,
            warningCount: warningCount
        )
    }

    /// A combined result for backup status widget
    public struct BackupStatusResult: Sendable {
        public let backups: [SimpleBackup]

        public var lastBackup: SimpleBackup? { backups.first }
        public var backupCount: Int { backups.count }

        public var lastBackupDate: Date? { lastBackup?.created }
        public var lastBackupName: String? { lastBackup?.name }
    }

    /// Fetch backup status
    @MainActor
    public static func fetchBackupStatus() async -> BackupStatusResult {
        let backups = await fetchBackups()
        return BackupStatusResult(backups: backups)
    }
}
