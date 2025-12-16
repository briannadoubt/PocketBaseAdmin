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
    @State private var collectionToEdit: CollectionModel?
    @State private var collectionToDelete: CollectionModel?
    @State private var showDeleteConfirmation = false

    @Environment(\.pocketbase) var pocketbase

    var body: some View {
        List(selection: $selection) {
            if state.isLoading && state.collections.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Connecting to server...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let error = state.error {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task {
                            await state.load(from: pocketbase)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else if !state.isLoading && collections.isEmpty && systemCollections.isEmpty {
                ContentUnavailableView {
                    Label("No Collections", systemImage: "folder")
                } description: {
                    Text("Create your first collection to get started.")
                } actions: {
                    Button("New Collection") {
                        showNewCollectionEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            }
            ForEach(collections, id: \.collection.id) { collectionState in
                NavigationLink(value: collectionState.collection) {
                    Label {
                        Text(collectionState.collection.name)
                    } icon: {
                        Image(collectionState.collection.type.image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .contextMenu {
                    CollectionMenuContent(
                        collection: collectionState.collection,
                        onEdit: {
                            collectionToEdit = collectionState.collection
                        },
                        onDuplicate: {
                            duplicateCollection(collectionState.collection)
                        },
                        onDelete: {
                            collectionToDelete = collectionState.collection
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            if !systemCollections.isEmpty {
                Section("System", isExpanded: $isSystemExpanded) {
                    ForEach(systemCollections, id: \.collection.id) { collectionState in
                        NavigationLink(value: collectionState.collection) {
                            Label {
                                Text(collectionState.collection.name)
                            } icon: {
                                Image(collectionState.collection.type.image)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .contextMenu {
                            CollectionMenuContent(
                                collection: collectionState.collection,
                                onEdit: {
                                    collectionToEdit = collectionState.collection
                                },
                                onDuplicate: {
                                    duplicateCollection(collectionState.collection)
                                },
                                onDelete: {
                                    collectionToDelete = collectionState.collection
                                    showDeleteConfirmation = true
                                }
                            )
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
        .sheet(item: $collectionToEdit) { collection in
            CollectionEditorView(
                collection: collection,
                onSave: { updatedCollection in
                    state.updateCollection(updatedCollection)
                }
            )
        }
        .alert("Delete Collection?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                collectionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    Task {
                        try? await state.delete(id: collection.id, using: pocketbase)
                        collectionToDelete = nil
                    }
                }
            }
        } message: {
            if let collection = collectionToDelete {
                Text("Are you sure you want to delete \"\(collection.name)\"? This will permanently delete all records in this collection. This action cannot be undone.")
            }
        }
    }

    private func duplicateCollection(_ collection: CollectionModel) {
        // Open the editor with a copy of the collection
        // User will need to change the name since it's a new collection
        // The CollectionEditorView will create a new collection when saved
        // Note: We pass the original collection but it will be treated as a template
        // since the editor detects duplicates by checking if a collection with the same name exists
        collectionToEdit = collection
    }
}
