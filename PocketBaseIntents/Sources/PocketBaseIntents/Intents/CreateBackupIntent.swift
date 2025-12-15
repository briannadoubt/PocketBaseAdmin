//
//  CreateBackupIntent.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Create a new PocketBase backup
public struct CreateBackupIntent: AppIntent {
    public static let title: LocalizedStringResource = "Create Backup"
    public static let description = IntentDescription("Create a new backup of your PocketBase database")

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Backup Name", description: "Optional custom name for the backup")
    public var name: String?

    public init() {}

    public init(name: String?) {
        self.name = name
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<BackupEntity> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()

            // Create the backup
            let backupName = name ?? "backup_\(Date().ISO8601Format())"
            try await client.admin.backups.create(name: backupName)

            // Fetch the created backup to get its details
            let backups = try await client.admin.backups.list()
            guard let createdBackup = backups.first(where: { $0.key.contains(backupName) || $0.key == backupName }) ?? backups.first else {
                throw ServerConfigurationError.serverError("Backup created but could not retrieve details")
            }

            let entity = BackupEntity(from: createdBackup)

            return .result(
                value: entity,
                dialog: "Backup '\(createdBackup.key)' created successfully"
            )
        } catch ServerConfigurationError.noServerURL {
            throw ServerConfigurationError.noServerURL
        } catch ServerConfigurationError.notAuthenticated {
            throw ServerConfigurationError.notAuthenticated
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Create backup \(\.$name)")
    }
}

/// List all PocketBase backups
public struct ListBackupsIntent: AppIntent {
    public static let title: LocalizedStringResource = "List Backups"
    public static let description = IntentDescription("List all available PocketBase backups")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[BackupEntity]> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            let backups = try await client.admin.backups.list()

            let entities = backups.map { BackupEntity(from: $0) }
            let count = entities.count

            return .result(
                value: entities,
                dialog: count == 1 ? "Found 1 backup" : "Found \(count) backups"
            )
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }
}

/// Restore a PocketBase backup (destructive - requires confirmation)
public struct RestoreBackupIntent: AppIntent {
    public static let title: LocalizedStringResource = "Restore Backup"
    public static let description = IntentDescription("Restore your PocketBase database from a backup. Warning: This will overwrite current data!")

    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false // Hide from Siri suggestions due to destructive nature

    @Parameter(title: "Backup", description: "The backup to restore")
    public var backup: BackupEntity

    public init() {}

    public init(backup: BackupEntity) {
        self.backup = backup
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            try await client.admin.backups.restore(name: backup.name)

            return .result(
                dialog: "Backup '\(backup.name)' restored. Server is restarting..."
            )
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Restore \(\.$backup)")
    }
}

/// Delete a PocketBase backup
public struct DeleteBackupIntent: AppIntent {
    public static let title: LocalizedStringResource = "Delete Backup"
    public static let description = IntentDescription("Delete a PocketBase backup")

    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false // Hide from Siri suggestions

    @Parameter(title: "Backup", description: "The backup to delete")
    public var backup: BackupEntity

    public init() {}

    public init(backup: BackupEntity) {
        self.backup = backup
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            try await client.admin.backups.delete(name: backup.name)

            return .result(
                dialog: "Backup '\(backup.name)' deleted"
            )
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$backup)")
    }
}
