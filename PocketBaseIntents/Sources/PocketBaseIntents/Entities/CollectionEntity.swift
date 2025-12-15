//
//  CollectionEntity.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import Foundation
import PocketBaseAdmin

/// Collection type for display purposes
public enum CollectionType: String, Codable, Sendable, AppEnum {
    case base
    case auth
    case view

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Collection Type")

    public static let caseDisplayRepresentations: [CollectionType: DisplayRepresentation] = [
        .base: DisplayRepresentation(title: "Base", image: .init(systemName: "rectangle.stack")),
        .auth: DisplayRepresentation(title: "Auth", image: .init(systemName: "person.badge.key")),
        .view: DisplayRepresentation(title: "View", image: .init(systemName: "eye"))
    ]
}

/// Represents a collection for App Intents
public struct CollectionEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Collection")
    public static let defaultQuery = CollectionQuery()

    public var id: String
    public var name: String
    public var type: CollectionType
    public var recordCount: Int
    public var isSystem: Bool

    public var displayRepresentation: DisplayRepresentation {
        let subtitle = recordCount == 1 ? "1 record" : "\(recordCount) records"
        let imageName: String
        switch type {
        case .base: imageName = "rectangle.stack"
        case .auth: imageName = "person.badge.key"
        case .view: imageName = "eye"
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitle)",
            image: .init(systemName: imageName)
        )
    }

    public init(
        id: String,
        name: String,
        type: CollectionType,
        recordCount: Int = 0,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.recordCount = recordCount
        self.isSystem = isSystem
    }

    public init(from collection: CollectionModel, recordCount: Int = 0) {
        self.id = collection.id
        self.name = collection.name
        self.type = CollectionType(rawValue: collection.type.rawValue) ?? .base
        self.recordCount = recordCount
        self.isSystem = collection.system
    }
}

public struct CollectionQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [CollectionEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }

    public func suggestedEntities() async throws -> [CollectionEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }
}

// MARK: - EntityStringQuery for searching collections by name
extension CollectionQuery: EntityStringQuery {
    public func entities(matching string: String) async throws -> [CollectionEntity] {
        // Would need to fetch from PocketBase - requires server connection
        []
    }
}
