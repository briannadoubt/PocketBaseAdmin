//
//  AuthProvidersView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct AuthProvidersView: View {
    @Environment(\.pocketbase) private var pocketbase

    private let providers: [OAuthProvider] = [
        OAuthProvider(name: "Google", icon: "g.circle.fill", color: .red),
        OAuthProvider(name: "GitHub", icon: "chevron.left.forwardslash.chevron.right", color: .primary),
        OAuthProvider(name: "Discord", icon: "bubble.left.and.bubble.right.fill", color: .indigo),
        OAuthProvider(name: "Microsoft", icon: "square.grid.2x2.fill", color: .blue),
        OAuthProvider(name: "Apple", icon: "apple.logo", color: .primary),
        OAuthProvider(name: "Facebook", icon: "f.circle.fill", color: .blue),
        OAuthProvider(name: "Twitter", icon: "at", color: .cyan),
        OAuthProvider(name: "Spotify", icon: "music.note", color: .green),
        OAuthProvider(name: "Twitch", icon: "play.tv.fill", color: .purple),
        OAuthProvider(name: "GitLab", icon: "chevron.left.forwardslash.chevron.right", color: .orange),
        OAuthProvider(name: "Bitbucket", icon: "chevron.left.forwardslash.chevron.right", color: .blue),
        OAuthProvider(name: "OIDC", icon: "lock.shield.fill", color: .secondary),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info banner
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OAuth Provider Configuration")
                            .font(.headline)
                        Text("OAuth providers are configured per auth collection. To set up providers, navigate to your auth collection's settings in the PocketBase Admin UI.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )

                // Supported providers
                VStack(alignment: .leading, spacing: 16) {
                    Text("Supported Providers")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 12)
                    ], spacing: 12) {
                        ForEach(providers) { provider in
                            ProviderCard(provider: provider)
                        }
                    }
                }

                // Link to admin UI
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure in Admin UI")
                        .font(.headline)

                    Link(destination: pocketbase.url.appendingPathComponent("/_/")) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Open PocketBase Admin")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Auth Providers")
    }
}

struct OAuthProvider: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

struct ProviderCard: View {
    let provider: OAuthProvider

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: provider.icon)
                .font(.title2)
                .foregroundStyle(provider.color)
                .frame(width: 32, height: 32)

            Text(provider.name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
