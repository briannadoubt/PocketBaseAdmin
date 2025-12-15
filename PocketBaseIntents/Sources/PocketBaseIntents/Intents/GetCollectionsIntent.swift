//
//  GetCollectionsIntent.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import AppIntents
import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Get all PocketBase collections
public struct GetCollectionsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Collections"
    public static let description = IntentDescription("Get a list of all collections in your PocketBase database")

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Include System Collections", default: false)
    public var includeSystem: Bool

    public init() {}

    public init(includeSystem: Bool = false) {
        self.includeSystem = includeSystem
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[CollectionEntity]> & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()
            let collections = try await client.admin.collections.list()

            var entities = collections.items.map { CollectionEntity(from: $0) }

            if !includeSystem {
                entities = entities.filter { !$0.isSystem }
            }

            let count = entities.count
            return .result(
                value: entities,
                dialog: count == 1 ? "Found 1 collection" : "Found \(count) collections"
            )
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }

    public static var parameterSummary: some ParameterSummary {
        When(\.$includeSystem, .equalTo, true) {
            Summary("Get all collections including system")
        } otherwise: {
            Summary("Get all collections")
        }
    }
}

/// Get record count for a specific collection
/// Note: This is a simplified version that doesn't query records directly.
/// Full implementation would require the main app to provide the count.
public struct GetRecordCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Record Count"
    public static let description = IntentDescription("Get the number of records in a collection")

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Collection")
    public var collection: CollectionEntity

    public init() {}

    public init(collection: CollectionEntity) {
        self.collection = collection
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        // Note: Getting record count requires the main app to track this
        // since it needs typed Record queries. Return the cached count.
        let count = collection.recordCount

        let dialog: IntentDialog
        if count == 1 {
            dialog = "\(collection.name) has 1 record"
        } else {
            dialog = "\(collection.name) has \(count) records"
        }

        return .result(value: count, dialog: dialog)
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Get record count for \(\.$collection)")
    }
}

/// Get server statistics
public struct GetServerStatsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Server Stats"
    public static let description = IntentDescription("Get statistics about your PocketBase server")

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let client = try await ServerConfiguration.shared.getClient()

            // Get collections
            let collections = try await client.admin.collections.list()
            let collectionCount = collections.items.count

            // Note: Getting total record count requires typed Record queries
            // which is complex in this generic context. Just show collection count.
            return .result(
                dialog: IntentDialog("Found \(collectionCount) collections")
            )
        } catch {
            throw ServerConfigurationError.serverError(error.localizedDescription)
        }
    }
}
