//
//  ImportCollectionsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI

struct ImportCollectionsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Import Collections", systemImage: "square.and.arrow.down")
        } description: {
            Text("Import collection schemas from another PocketBase instance or JSON file.")
        } actions: {
            Button("Import from File") {
                // TODO: Implement file import
            }
            .buttonStyle(.borderedProminent)
            
            Button("Import from URL") {
                // TODO: Implement URL import
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("Import Collections")
    }
}
