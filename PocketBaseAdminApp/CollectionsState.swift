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
            let newCollections = try await Admin(pocketbase: pocketbase)
                .collections()
                .items
                .map {
                    CollectionState(collection: $0)
                }
            await MainActor.run {
                collections = newCollections
            }
        } catch {
            logger.error("Error loading collections: \(error)")
            self.error = error.localizedDescription
        }
    }
}

extension OrderedDictionary: @retroactive RandomAccessCollection {
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
