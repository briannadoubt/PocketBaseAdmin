//
//  ContentView.swift
//  PocketBase Watch App
//
//  Created by Brianna Zamora on 7/2/25.
//

import SwiftUI
#if canImport(PocketBaseIntents)
import PocketBaseIntents
#endif

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isChecking = true

    var body: some View {
        Group {
            if isChecking {
                ProgressView("Checking...")
            } else if isAuthenticated {
                AuthenticatedContentView()
            } else {
                NotAuthenticatedView()
            }
        }
        .task {
            await checkAuthentication()
        }
    }

    private func checkAuthentication() async {
        #if canImport(PocketBaseIntents)
        let config = ServerConfiguration.shared
        isAuthenticated = await config.isConfigured && await config.authToken != nil
        #else
        isAuthenticated = false
        #endif
        isChecking = false
    }
}

/// Main content when authenticated
struct AuthenticatedContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tag(0)

            ActionsView()
                .tag(1)

            LogsListView()
                .tag(2)

            CollectionsListView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
    }
}

/// Shown when not logged in - offers login or iPhone sync
struct NotAuthenticatedView: View {
    @State private var showLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text("PocketBase Admin")
                    .font(.headline)

                Text("Sign in to manage your server")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Divider()
                    .padding(.vertical, 4)

                // Sign in on Watch
                Button {
                    showLogin = true
                } label: {
                    Label("Sign In", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Or use iPhone
                Text("Or sign in on iPhone—credentials sync automatically.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding()
        }
        .sheet(isPresented: $showLogin) {
            WatchLoginView()
        }
    }
}

/// Login view for Watch (standalone login)
struct WatchLoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(watchOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        #if os(watchOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign In") {
                        Task { await signIn() }
                    }
                    .disabled(isLoading || serverURL.isEmpty || email.isEmpty || password.isEmpty)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Validate URL
        guard let url = URL(string: serverURL.hasPrefix("http") ? serverURL : "https://\(serverURL)") else {
            errorMessage = "Invalid server URL"
            return
        }

        #if canImport(PocketBaseIntents)
        do {
            // Save server URL
            await ServerConfiguration.shared.setServerURL(url)

            // Create client and authenticate
            let client = try await ServerConfiguration.shared.getClient()
            let auth = try await client.admin.auth.withPassword(email: email, password: password)

            // Save token to shared Keychain
            await ServerConfiguration.shared.setAuthToken(auth.token)

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Intents not available"
        #endif
    }
}

#Preview("Authenticated") {
    AuthenticatedContentView()
}

#Preview("Not Authenticated") {
    NotAuthenticatedView()
}
