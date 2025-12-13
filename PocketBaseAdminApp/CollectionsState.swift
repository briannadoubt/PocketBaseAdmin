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

    var logger = Logger(subsystem: "PocketBaseAdminApp", category: "CollectionsState")

    func load(from pocketbase: PocketBase) async {
        do {
            let newCollections = try await pocketbase.admin.collections
                .list()
                .items
                .map {
                    CollectionState(collection: $0)
                }
            await MainActor.run {
                collections = newCollections
            }
        } catch {
            logger.error("Error loading collections: \(error)")
            self.error = String(describing: error)
        }
    }

    func addCollection(_ collection: CollectionModel) {
        let state = CollectionState(collection: collection)
        collections.append(state)
    }

    func updateCollection(_ collection: CollectionModel) {
        if let index = collections.firstIndex(where: { $0.collection.id == collection.id }) {
            collections[index].collection = collection
        }
    }

    func delete(id: String, using pocketbase: PocketBase) async throws {
        try await pocketbase.admin.collections.delete(id: id)
        collections.removeAll { $0.collection.id == id }
    }
}

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
