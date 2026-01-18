//
//  CollectionsState.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import Collections
import PocketBaseAdmin
import PocketBase
import OSLog

@Observable
@MainActor
final class CollectionsState {
    var collections: [CollectionState] = []
    var error: String?
    var isLoading: Bool = false
    var authExpired: Bool = false

    var retryCount: Int = 0
    var maxRetryCount: Int = 5

    var logger = Logger(subsystem: "PocketBaseAdminApp", category: "CollectionsState")

    /// User-created collections (non-system)
    var userCollections: [CollectionState] {
        collections.filter { !$0.collection.system }
    }

    /// System collections (prefixed with underscore, like _mfas, _otps, etc.)
    var systemCollections: [CollectionState] {
        collections.filter { $0.collection.system }
    }

    func load(from pocketbase: PocketBase) async {
        isLoading = true
        error = nil

        // Debug: Check auth state
        logger.info("Loading collections - authStore.isValid: \(pocketbase.authStore.isValid), hasToken: \(pocketbase.authStore.token != nil)")
        if let token = pocketbase.authStore.token {
            logger.info("Token prefix: \(String(token.prefix(20)))...")
        }

        do {
            let loadedCollections = try await pocketbase.admin.collections
                .list()
                .items

            let newCollections = loadedCollections.map {
                CollectionState(collection: $0)
            }
            collections = newCollections
            isLoading = false
            retryCount = 0

            // Index collections for Spotlight search
            await SpotlightIndexer.shared.indexCollections(loadedCollections)
        } catch let loadError {
            let nsError = loadError as NSError

            // Check if it's a connection error that might be due to server not ready
            if nsError.domain == NSURLErrorDomain,
               [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCancelled].contains(nsError.code) {
                retryCount += 1

                if retryCount < maxRetryCount {
                    logger.info("Server not ready, retrying to load collections... (Attempt \(self.retryCount)/\(self.maxRetryCount))")
                    try? await Task.sleep(for: .seconds(1))
                    await load(from: pocketbase)
                    return
                }
            }

            // Check if it's a 401 Unauthorized error - signal auth expired
            if let networkError = loadError as? NetworkError,
               case .invalidResponse(_, let statusCode, _, _) = networkError,
               statusCode == 401 {
                logger.warning("Authentication expired or invalid")
                authExpired = true
                self.error = "Session expired. Please log in again."
                isLoading = false
                retryCount = 0
                return
            }

            logger.error("Error loading collections: \(loadError)")
            self.error = String(describing: loadError)
            isLoading = false
            retryCount = 0
        }
    }

    func addCollection(_ collection: CollectionModel) {
        let state = CollectionState(collection: collection)
        collections.append(state)

        // Index new collection for Spotlight
        Task {
            await SpotlightIndexer.shared.indexCollections([collection])
        }
    }

    func updateCollection(_ collection: CollectionModel) {
        if let index = collections.firstIndex(where: { $0.collection.id == collection.id }) {
            collections[index].collection = collection

            // Re-index updated collection for Spotlight
            Task {
                await SpotlightIndexer.shared.indexCollections([collection])
            }
        }
    }

    func delete(id: String, using pocketbase: PocketBase) async throws {
        try await pocketbase.admin.collections.delete(id: id)
        collections.removeAll { $0.collection.id == id }

        // Remove from Spotlight index
        await SpotlightIndexer.shared.removeCollection(id: id)
    }
}

// MARK: - OrderedDictionary RandomAccessCollection Conformance

/// Extends OrderedDictionary to conform to RandomAccessCollection for use with SwiftUI's ForEach.
/// This retroactive conformance is required because OrderedDictionary (from swift-collections)
/// doesn't natively conform to RandomAccessCollection. The @MainActor annotation ensures
/// thread-safe access when used in SwiftUI views.
///
/// Note: Retroactive conformances should generally be avoided, but this is acceptable here
/// because OrderedDictionary is unlikely to add conflicting conformance in the future.
extension OrderedDictionary: @retroactive @MainActor RandomAccessCollection {
    public subscript(position: Int) -> (key: Key, value: Value) {
        (elements.keys[position], values[position])
    }

    public var startIndex: Int {
        self.values.startIndex
    }

    public var endIndex: Int {
        self.values.endIndex
    }
}
