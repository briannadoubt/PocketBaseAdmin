//
//  CollectionsList.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
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
    
    @Environment(\.pocketbase) var pocketbase
    
    var body: some View {
        List(selection: $selection) {
            ForEach(collections, id: \.collection.id) { state in
                NavigationLink(value: state.collection) {
                    Text(state.collection.name)
                }
            }
            if !systemCollections.isEmpty {
                Section("System", isExpanded: $isSystemExpanded) {
                    ForEach(systemCollections, id: \.collection.id) { state in
                        NavigationLink(value: state.collection) {
                            Text(state.collection.name)
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
            if let collection = state.collections.first(
                where: {
                    $0.collection.id == collection.id
                }
            ) {
                CollectionView(state: collection)
            }
        }
        .task {
            await state.load(from: pocketbase)
        }
        .environment(state)
        .navigationTitle("Collections")
    }
}
