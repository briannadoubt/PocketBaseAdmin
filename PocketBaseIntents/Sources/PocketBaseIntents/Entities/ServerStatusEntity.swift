//
//  ServerStatusEntity.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import Foundation

/// Represents the server status for App Intents
public struct ServerStatusEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server Status")
    public static let defaultQuery = ServerStatusQuery()

    public var id: String
    public var isOnline: Bool
    public var latency: TimeInterval?
    public var version: String?
    public var checkedAt: Date

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: isOnline ? "Online" : "Offline",
            subtitle: latency.map { "\(Int($0 * 1000))ms" } ?? "",
            image: .init(systemName: isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
        )
    }

    public init(
        id: String = UUID().uuidString,
        isOnline: Bool,
        latency: TimeInterval? = nil,
        version: String? = nil,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.isOnline = isOnline
        self.latency = latency
        self.version = version
        self.checkedAt = checkedAt
    }
}

public struct ServerStatusQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ServerStatusEntity] {
        // Server status is always fetched fresh, not stored
        []
    }

    public func suggestedEntities() async throws -> [ServerStatusEntity] {
        []
    }
}
