//
//  BackupEntity.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import Foundation
import PocketBaseAdmin

/// Represents a backup for App Intents
public struct BackupEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Backup")
    public static let defaultQuery = BackupQuery()

    public var id: String
    public var name: String
    public var size: Int64
    public var created: Date

    public var displayRepresentation: DisplayRepresentation {
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(sizeFormatted) - \(created.formatted(date: .abbreviated, time: .shortened))",
            image: .init(systemName: "archivebox.fill")
        )
    }

    public init(id: String, name: String, size: Int64, created: Date) {
        self.id = id
        self.name = name
        self.size = size
        self.created = created
    }

    public init(from backup: BackupModel) {
        self.id = backup.key
        self.name = backup.key
        self.size = Int64(backup.size)
        self.created = backup.modified
    }
}

public struct BackupQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [BackupEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }

    public func suggestedEntities() async throws -> [BackupEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }
}
