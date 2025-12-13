//
//  AuthProvidersView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI

struct AuthProvidersView: View {
    var body: some View {
        ContentUnavailableView {
            Label("OAuth Providers", systemImage: "person.badge.key")
        } description: {
            Text("Configure OAuth authentication providers like Google, GitHub, Discord, etc.")
        } actions: {
            Button("Add Provider") {
                // TODO: Implement provider setup
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Auth Providers")
    }
}
