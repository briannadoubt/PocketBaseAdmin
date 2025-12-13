//
//  CollectionsList.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct CollectionsList: View {
    @Environment(CollectionsState.self) private var state

    var collections: [CollectionState] {
        state.collections.filter({ !$0.collection.system })
    }

    var systemCollections: [CollectionState] {
        state.collections.filter({ $0.collection.system })
    }

    @Binding var selection: String?

    @State private var searchQuery: String = ""
    @State private var isSystemExpanded: Bool = false
    @State private var showNewCollectionEditor = false

    @Environment(\.pocketbase) var pocketbase

    var body: some View {
        List(selection: $selection) {
            ForEach(collections, id: \.collection.id) { collectionState in
                NavigationLink(value: collectionState.collection) {
                    Text(collectionState.collection.name)
                }
            }
            if !systemCollections.isEmpty {
                Section("System", isExpanded: $isSystemExpanded) {
                    ForEach(systemCollections, id: \.collection.id) { collectionState in
                        NavigationLink(value: collectionState.collection) {
                            Text(collectionState.collection.name)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchQuery)
        .refreshable {
            await state.load(from: pocketbase)
        }
        .navigationDestination(for: CollectionModel.self) { collection in
            if let collectionState = state.collections.first(
                where: {
                    $0.collection.id == collection.id
                }
            ) {
                CollectionView(state: collectionState)
            }
        }
        .task {
            await state.load(from: pocketbase)
        }
        .environment(state)
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Collection", systemImage: "plus") {
                    showNewCollectionEditor = true
                }
            }
        }
        .sheet(isPresented: $showNewCollectionEditor) {
            CollectionEditorView(
                collection: nil,
                onSave: { newCollection in
                    state.addCollection(newCollection)
                }
            )
        }
    }
}
