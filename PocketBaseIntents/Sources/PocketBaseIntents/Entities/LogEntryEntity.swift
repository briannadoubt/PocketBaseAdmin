//
//  LogEntryEntity.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import Foundation
import SwiftUI
import PocketBaseAdmin

/// Log level for App Intents display purposes
public enum IntentLogLevel: Int, Codable, Sendable, AppEnum {
    case debug = -4
    case info = 0
    case warning = 4
    case error = 8

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Log Level")

    public static let caseDisplayRepresentations: [IntentLogLevel: DisplayRepresentation] = [
        .debug: DisplayRepresentation(title: "Debug", image: .init(systemName: "ant")),
        .info: DisplayRepresentation(title: "Info", image: .init(systemName: "info.circle")),
        .warning: DisplayRepresentation(title: "Warning", image: .init(systemName: "exclamationmark.triangle")),
        .error: DisplayRepresentation(title: "Error", image: .init(systemName: "xmark.circle"))
    ]

    public var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
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

    public init(from level: Int) {
        switch level {
        case ..<0: self = .debug
        case 0..<4: self = .info
        case 4..<8: self = .warning
        default: self = .error
        }
    }

    public init(from level: PocketBaseAdmin.LogLevel) {
        self.init(from: level.rawValue)
    }
}

/// Represents a log entry for App Intents
public struct LogEntryEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Log Entry")
    public static let defaultQuery = LogEntryQuery()

    public var id: String
    public var message: String
    public var level: IntentLogLevel
    public var created: Date
    public var data: [String: String]?

    public var displayRepresentation: DisplayRepresentation {
        let imageName: String
        switch level {
        case .debug: imageName = "ant"
        case .info: imageName = "info.circle"
        case .warning: imageName = "exclamationmark.triangle"
        case .error: imageName = "xmark.circle"
        }
        return DisplayRepresentation(
            title: "\(message)",
            subtitle: "\(level.name) - \(created.formatted(date: .omitted, time: .shortened))",
            image: .init(systemName: imageName)
        )
    }

    public init(
        id: String,
        message: String,
        level: IntentLogLevel,
        created: Date,
        data: [String: String]? = nil
    ) {
        self.id = id
        self.message = message
        self.level = level
        self.created = created
        self.data = data
    }

    public init(from log: LogModel) {
        self.id = log.id
        self.message = log.message
        self.level = IntentLogLevel(from: log.level)
        self.created = log.created
        self.data = nil // LogData is a struct, not [String: String]
    }
}

public struct LogEntryQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [LogEntryEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }

    public func suggestedEntities() async throws -> [LogEntryEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }
}
