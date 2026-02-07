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

    let connectionName: String?
    let connectionURL: String?
    let onAuthenticated: () -> Void
    let onSwitchConnection: (() -> Void)?

    init(
        connectionName: String? = nil,
        connectionURL: String? = nil,
        onSwitchConnection: (() -> Void)? = nil,
        onAuthenticated: @escaping () -> Void
    ) {
        self.connectionName = connectionName
        self.connectionURL = connectionURL
        self.onSwitchConnection = onSwitchConnection
        self.onAuthenticated = onAuthenticated
    }

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Connection info header
                if let connectionName, let connectionURL {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Signing into")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 4) {
                            Text(connectionName)
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(connectionURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        if let onSwitchConnection {
                            Button {
                                onSwitchConnection()
                            } label: {
                                Label("Switch Connection", systemImage: "arrow.left.arrow.right")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }

                // Logo and title
                VStack(spacing: 16) {
                    Image(.base)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .padding(20)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }

                    Text("PocketBase Admin")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Sign in to manage your server")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Login form
                VStack(spacing: 20) {
                    if needsInitialSetup {
                        initialSetupCard
                    } else {
                        loginCard
                    }
                }
                .frame(maxWidth: 360)

                Spacer()
                Spacer()
            }
            .padding(40)
        }
        .task {
            await checkAdminStatus()
        }
    }

    @ViewBuilder
    private var loginCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("admin@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("••••••••", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .onSubmit {
                        if !email.isEmpty && !password.isEmpty {
                            Task { await login() }
                        }
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await login() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 20)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Text("Admin accounts can only be created by existing admins or during initial setup.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var initialSetupCard: some View {
        VStack(spacing: 16) {
            // Warning banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Initial Setup Required")
                        .font(.headline)
                    Text("Create the first admin account to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("admin@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("Minimum 8 characters", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await createFirstAdmin() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Create Admin Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 20)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(email.isEmpty || password.count < 8 || isLoading)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private func checkAdminStatus() async {
        do {
            let collection = pocketbase.collection(Superuser.self)
            _ = try await collection.listAuthMethods()
            needsInitialSetup = false
        } catch {
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
            let collection = pocketbase.collection(Superuser.self)

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
