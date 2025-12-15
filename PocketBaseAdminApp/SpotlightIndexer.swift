//
//  SpotlightIndexer.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import PocketBase
import PocketBaseAdmin
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Indexes PocketBase data for Spotlight search
@MainActor
public final class SpotlightIndexer {
    public static let shared = SpotlightIndexer()

    private let domainIdentifier = "com.briannadoubt.PocketBaseAdmin"
    private let searchableIndex = CSSearchableIndex.default()

    private init() {}

    // MARK: - Thumbnail Rendering

    /// Renders an SF Symbol to PNG data for Spotlight thumbnails
    private static func renderSFSymbol(named name: String) -> Data? {
        #if os(macOS)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .medium)
        let configuredImage = image.withSymbolConfiguration(config) ?? image

        let size = NSSize(width: 64, height: 64)
        let coloredImage = NSImage(size: size, flipped: false) { rect in
            NSColor.secondaryLabelColor.setFill()
            configuredImage.draw(in: rect)
            return true
        }

        guard let tiffData = coloredImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .medium)
        guard let image = UIImage(systemName: name, withConfiguration: config) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let pngData = renderer.pngData { context in
            UIColor.secondaryLabel.setFill()
            image.draw(in: CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return pngData
        #endif
    }

    // MARK: - Collections

    /// Index all collections for Spotlight
    public func indexCollections(_ collections: [CollectionModel]) async {
        let items = collections.map { collection -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)

            // Basic info
            attributeSet.title = collection.name
            attributeSet.contentDescription = "\(collection.type.displayName) collection in PocketBase"

            // Keywords for search
            attributeSet.keywords = [
                collection.name,
                collection.type.displayName,
                "collection",
                "pocketbase",
                "database"
            ]

            // Display hints
            attributeSet.displayName = collection.name

            // Thumbnail - render SF Symbol based on collection type
            let thumbnailName: String
            switch collection.type {
            case .base:
                thumbnailName = "rectangle.stack"
            case .auth:
                thumbnailName = "person.badge.key"
            case .view:
                thumbnailName = "eye"
            }
            attributeSet.thumbnailData = Self.renderSFSymbol(named: thumbnailName)

            // Additional metadata
            if let fields = collection.schema {
                let fieldNames = fields.map { $0.name }
                attributeSet.keywords?.append(contentsOf: fieldNames)
                attributeSet.contentDescription = "\(collection.type.displayName) collection with \(fields.count) fields: \(fieldNames.joined(separator: ", "))"
            }

            return CSSearchableItem(
                uniqueIdentifier: "collection-\(collection.id)",
                domainIdentifier: "\(domainIdentifier).collections",
                attributeSet: attributeSet
            )
        }

        do {
            try await searchableIndex.indexSearchableItems(items)
            print("Spotlight: Indexed \(items.count) collections")
        } catch {
            print("Spotlight: Failed to index collections: \(error)")
        }
    }

    /// Remove a collection from Spotlight index
    public func removeCollection(id: String) async {
        do {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: ["collection-\(id)"])
            print("Spotlight: Removed collection \(id)")
        } catch {
            print("Spotlight: Failed to remove collection: \(error)")
        }
    }

    /// Remove all collections from Spotlight index
    public func removeAllCollections() async {
        do {
            try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["\(domainIdentifier).collections"])
            print("Spotlight: Removed all collections")
        } catch {
            print("Spotlight: Failed to remove all collections: \(error)")
        }
    }

    // MARK: - Backups

    /// Index all backups for Spotlight
    public func indexBackups(_ backups: [BackupModel]) async {
        let items = backups.map { backup -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .data)

            attributeSet.title = backup.key
            attributeSet.contentDescription = "PocketBase backup - \(backup.formattedSize)"

            attributeSet.keywords = [
                backup.key,
                "backup",
                "database",
                "pocketbase"
            ]

            attributeSet.displayName = backup.key
            attributeSet.contentCreationDate = backup.modified

            // File size
            attributeSet.fileSize = NSNumber(value: backup.size)

            return CSSearchableItem(
                uniqueIdentifier: "backup-\(backup.key)",
                domainIdentifier: "\(domainIdentifier).backups",
                attributeSet: attributeSet
            )
        }

        do {
            try await searchableIndex.indexSearchableItems(items)
            print("Spotlight: Indexed \(items.count) backups")
        } catch {
            print("Spotlight: Failed to index backups: \(error)")
        }
    }

    /// Remove all backups from Spotlight index
    public func removeAllBackups() async {
        do {
            try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["\(domainIdentifier).backups"])
            print("Spotlight: Removed all backups")
        } catch {
            print("Spotlight: Failed to remove all backups: \(error)")
        }
    }

    // MARK: - Full Reset

    /// Remove all indexed items
    public func deleteAllIndexes() async {
        do {
            try await searchableIndex.deleteAllSearchableItems()
            print("Spotlight: Deleted all indexes")
        } catch {
            print("Spotlight: Failed to delete all indexes: \(error)")
        }
    }
}

// MARK: - CollectionModel Extension

extension CollectionModelType {
    var displayName: String {
        switch self {
        case .base:
            return "Base"
        case .auth:
            return "Auth"
        case .view:
            return "View"
        }
    }
}

// MARK: - Spotlight Activity Types

extension NSUserActivity {
    /// Create an activity for viewing a collection
    static func viewCollection(_ collection: CollectionModel) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.briannadoubt.PocketBaseAdmin.viewCollection")
        activity.title = "View \(collection.name)"
        activity.userInfo = ["collectionId": collection.id]
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.isEligibleForHandoff = true

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = collection.name
        attributes.contentDescription = "\(collection.type.displayName) collection"
        activity.contentAttributeSet = attributes

        return activity
    }

    /// Create an activity for viewing backups
    static func viewBackups() -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.briannadoubt.PocketBaseAdmin.viewBackups")
        activity.title = "View Backups"
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = "PocketBase Backups"
        attributes.contentDescription = "View and manage database backups"
        activity.contentAttributeSet = attributes

        return activity
    }

    /// Create an activity for viewing logs
    static func viewLogs() -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.briannadoubt.PocketBaseAdmin.viewLogs")
        activity.title = "View Logs"
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = "PocketBase Logs"
        attributes.contentDescription = "View server logs and errors"
        activity.contentAttributeSet = attributes

        return activity
    }

    /// Create an activity for checking server status
    static func checkServerStatus() -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.briannadoubt.PocketBaseAdmin.checkStatus")
        activity.title = "Check Server Status"
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = "PocketBase Server Status"
        attributes.contentDescription = "Check if server is online"
        activity.contentAttributeSet = attributes

        return activity
    }
}
