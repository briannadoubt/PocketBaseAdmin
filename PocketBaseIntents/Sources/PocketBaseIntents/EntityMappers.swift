//
//  EntityMappers.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import SwiftUI

// MARK: - Simple Server Status

/// A simple, Sendable struct representing server status for widgets and Watch app
public struct SimpleServerStatus: Sendable, Equatable {
    public let isOnline: Bool
    public let latency: TimeInterval?
    public let version: String?
    public let checkedAt: Date

    public init(isOnline: Bool, latency: TimeInterval? = nil, version: String? = nil, checkedAt: Date = Date()) {
        self.isOnline = isOnline
        self.latency = latency
        self.version = version
        self.checkedAt = checkedAt
    }

    public init(from entity: ServerStatusEntity) {
        self.isOnline = entity.isOnline
        self.latency = entity.latency
        self.version = entity.version
        self.checkedAt = entity.checkedAt
    }

    public static let offline = SimpleServerStatus(isOnline: false)
}

// MARK: - Simple Collection

/// A simple, Sendable struct representing a collection for widgets and Watch app
public struct SimpleCollection: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: SimpleCollectionType
    public let recordCount: Int
    public let isSystem: Bool

    public init(id: String, name: String, type: SimpleCollectionType, recordCount: Int = 0, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.recordCount = recordCount
        self.isSystem = isSystem
    }

    public init(from entity: CollectionEntity) {
        self.id = entity.id
        self.name = entity.name
        self.type = SimpleCollectionType(from: entity.type)
        self.recordCount = entity.recordCount
        self.isSystem = entity.isSystem
    }
}

/// Simple collection type for widgets
public enum SimpleCollectionType: String, Sendable, Equatable {
    case base
    case auth
    case view

    public init(from type: CollectionType) {
        switch type {
        case .base: self = .base
        case .auth: self = .auth
        case .view: self = .view
        }
    }

    public var icon: String {
        switch self {
        case .base: return "rectangle.stack"
        case .auth: return "person.badge.key"
        case .view: return "eye"
        }
    }

    public var color: Color {
        switch self {
        case .base: return .blue
        case .auth: return .green
        case .view: return .purple
        }
    }
}

// MARK: - Simple Log Entry

/// A simple, Sendable struct representing a log entry for widgets and Watch app
public struct SimpleLogEntry: Sendable, Identifiable, Equatable {
    public let id: String
    public let message: String
    public let level: SimpleLogLevel
    public let created: Date

    public init(id: String, message: String, level: SimpleLogLevel, created: Date) {
        self.id = id
        self.message = message
        self.level = level
        self.created = created
    }

    public init(from entity: LogEntryEntity) {
        self.id = entity.id
        self.message = entity.message
        self.level = SimpleLogLevel(from: entity.level)
        self.created = entity.created
    }
}

/// Simple log level for widgets
public enum SimpleLogLevel: Int, Sendable, Equatable {
    case debug = -4
    case info = 0
    case warning = 4
    case error = 8

    public init(from level: IntentLogLevel) {
        switch level {
        case .debug: self = .debug
        case .info: self = .info
        case .warning: self = .warning
        case .error: self = .error
        }
    }

    public var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    public var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }

    public var name: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

// MARK: - Simple Backup

/// A simple, Sendable struct representing a backup for widgets and Watch app
public struct SimpleBackup: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let size: Int64
    public let created: Date

    public init(id: String, name: String, size: Int64, created: Date) {
        self.id = id
        self.name = name
        self.size = size
        self.created = created
    }

    public init(from entity: BackupEntity) {
        self.id = entity.id
        self.name = entity.name
        self.size = entity.size
        self.created = entity.created
    }

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
