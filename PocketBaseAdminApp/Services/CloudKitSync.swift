//
//  CloudKitSync.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import Foundation
import CloudKit

/// Syncs connection configurations to CloudKit for cross-device access
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
final class CloudKitSync: Sendable {
    /// CloudKit record type for connections
    private static let recordType = "PocketBaseConnection"

    /// CloudKit container
    private let container: CKContainer

    /// Private database for user data
    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    // MARK: - Initialization

    init(containerIdentifier: String = "iCloud.com.briannadoubt.PocketBaseAdmin") {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - CRUD Operations

    /// Save a connection to CloudKit
    func save(_ connection: Connection) async throws {
        let record = toRecord(connection)
        _ = try await database.save(record)
    }

    /// Fetch all connections from CloudKit
    func fetchAll() async throws -> [Connection] {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let (results, _) = try await database.records(matching: query)

        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return fromRecord(record)
        }
    }

    /// Delete a connection from CloudKit
    func delete(recordID: String) async throws {
        let ckRecordID = CKRecord.ID(recordName: recordID)
        _ = try await database.deleteRecord(withID: ckRecordID)
    }

    /// Setup push notifications for sync
    func setupSubscription() async throws {
        let subscriptionID = "connection-changes"

        // Check if subscription already exists
        do {
            _ = try await database.subscription(for: subscriptionID)
            return // Already subscribed
        } catch {
            // Subscription doesn't exist, create it
        }

        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await database.save(subscription)
    }

    // MARK: - Record Conversion

    private func toRecord(_ connection: Connection) -> CKRecord {
        let recordID: CKRecord.ID
        if let existingID = connection.cloudKitRecordID {
            recordID = CKRecord.ID(recordName: existingID)
        } else {
            recordID = CKRecord.ID(recordName: connection.id.uuidString)
        }

        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["connectionID"] = connection.id.uuidString
        record["name"] = connection.name
        record["host"] = connection.host
        record["port"] = connection.port as NSNumber
        record["useTLS"] = (connection.useTLS ? 1 : 0) as NSNumber
        record["isLocal"] = (connection.isLocal ? 1 : 0) as NSNumber
        record["discoveredViaBonjour"] = (connection.discoveredViaBonjour ? 1 : 0) as NSNumber
        record["lastConnected"] = connection.lastConnected

        return record
    }

    private func fromRecord(_ record: CKRecord) -> Connection? {
        guard let connectionIDString = record["connectionID"] as? String,
              let connectionID = UUID(uuidString: connectionIDString),
              let name = record["name"] as? String,
              let host = record["host"] as? String,
              let portNumber = record["port"] as? NSNumber else {
            return nil
        }

        let port = portNumber.intValue
        let useTLS = (record["useTLS"] as? NSNumber)?.boolValue ?? false
        let isLocal = (record["isLocal"] as? NSNumber)?.boolValue ?? false
        let discoveredViaBonjour = (record["discoveredViaBonjour"] as? NSNumber)?.boolValue ?? false
        let lastConnected = record["lastConnected"] as? Date

        return Connection(
            id: connectionID,
            name: name,
            host: host,
            port: port,
            useTLS: useTLS,
            isLocal: isLocal,
            discoveredViaBonjour: discoveredViaBonjour,
            lastConnected: lastConnected,
            cloudKitRecordID: record.recordID.recordName
        )
    }
}

// MARK: - CloudKit Account Status

@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
extension CloudKitSync {
    /// Check if iCloud is available
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Get the current user's iCloud account hash for Bonjour filtering
    func getiCloudAccountHash() async throws -> String? {
        let status = try await checkAccountStatus()
        guard status == .available else { return nil }

        let userID = try await container.userRecordID()
        // Create a hash of the user record name
        let data = Data(userID.recordName.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { ptr in
            // Simple hash - in production you'd use CryptoKit
            for (i, byte) in ptr.enumerated() {
                hash[i % 32] ^= byte
            }
        }
        return Data(hash).base64EncodedString()
    }
}
