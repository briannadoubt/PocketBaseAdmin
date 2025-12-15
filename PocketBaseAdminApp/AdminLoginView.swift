//
//  AdminLoginView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

/// Admin-specific login view that only shows login (no signup).
/// Admins cannot sign up - they must be created by other admins or via the initial setup.
struct AdminLoginView: View {
    @Environment(\.pocketbase) private var pocketbase

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var needsInitialSetup = false
    @State private var installerToken: String?

    let onAuthenticated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if needsInitialSetup {
                    initialSetupSection
                } else {
                    loginSection
                }
            }
            .navigationTitle("Admin Login")
            .task {
                await checkAdminStatus()
            }
        }
    }

    @ViewBuilder
    private var loginSection: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif

            SecureField("Password", text: $password)
                .textContentType(.password)
        } header: {
            Text("Admin Credentials")
        } footer: {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }

        Section {
            Button {
                Task {
                    await login()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }

        Section {
            Text("Admin accounts can only be created by existing admins or during initial setup.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var initialSetupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Initial Setup Required", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text("No admin account exists yet. Create the first admin account to get started.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }

        Section("Create First Admin") {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
        }

        Section {
            Button {
                Task {
                    await createFirstAdmin()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Admin Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(email.isEmpty || password.count < 8 || isLoading)
        } footer: {
            Text("Password must be at least 8 characters.")
                .font(.caption)
        }

        if let errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func checkAdminStatus() async {
        // Check if any admins exist by trying to list auth methods
        do {
            let collection = pocketbase.collection(Superuser.self)
            _ = try await collection.listAuthMethods()
            needsInitialSetup = false
        } catch {
            // If we get a 404 or specific error, might need setup
            // For now, assume login is available
            needsInitialSetup = false
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let collection = pocketbase.collection(Superuser.self)
            _ = try await collection.authWithPassword(
                email,
                password: password
            )
            onAuthenticated()
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }

    private func createFirstAdmin() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Create first admin via the _superusers collection
            let collection = pocketbase.collection(Superuser.self)

            // First try to create the admin
            let newAdmin = Superuser(
                email: email,
                verified: true,
                emailVisibility: false
            )

            _ = try await collection.create(
                newAdmin,
                password: password,
                passwordConfirm: password
            )

            // Then login with the new credentials
            _ = try await collection.authWithPassword(
                email,
                password: password
            )

            onAuthenticated()
        } catch {
            errorMessage = "Failed to create admin: \(error.localizedDescription)"
        }
    }
}
