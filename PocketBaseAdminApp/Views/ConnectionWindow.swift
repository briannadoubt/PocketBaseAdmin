//
//  ConnectionWindow.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseUI
import PocketBaseAdmin

/// Window content for a specific PocketBase connection
struct ConnectionWindow: View {
    let connectionID: UUID?
    var onSwitchConnection: (() -> Void)?

    @Environment(ConnectionHub.self) private var hub
    #if os(macOS)
    @Environment(\.serverManager) private var serverManager
    #endif

    @State private var pocketbase: PocketBase?
    @State private var isConnecting = true
    @State private var connectionError: String?
    @State private var needsSetup = false
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true
    @State private var hasAttemptedAutoStart = false

    var body: some View {
        Group {
            if let connectionID, let connection = hub.connections.first(where: { $0.id == connectionID }) {
                connectionContent(for: connection)
            } else {
                noConnectionView
            }
        }
    }

    // MARK: - Connection Content

    @ViewBuilder
    private func connectionContent(for connection: Connection) -> some View {
        #if os(macOS)
        if connection.isLocal {
            localConnectionContent(for: connection)
        } else {
            remoteConnectionContent(for: connection)
        }
        #else
        remoteConnectionContent(for: connection)
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private func localConnectionContent(for connection: Connection) -> some View {
        if let serverManager {
            switch serverManager.state {
            case .stopped:
                serverStoppedView(connection: connection)
            case .needsSetup:
                localSetupView(connection: connection)
            case .downloading:
                downloadingView()
            case .starting:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Starting PocketBase server...")
                        .font(.headline)
                }
            case .running:
                remoteConnectionContent(for: connection)
            case .stopping:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Stopping server...")
                        .font(.headline)
                }
            case .error(let message):
                serverErrorView(message: message, connection: connection)
            }
        } else {
            // No server manager, treat as remote
            remoteConnectionContent(for: connection)
        }
    }

    @ViewBuilder
    private func localSetupView(connection: Connection) -> some View {
        LocalSuperuserSetupView(serverManager: serverManager!) {
            // After setup completes, start the server
            Task {
                await serverManager?.startAfterSetup()
            }
        }
    }

    @ViewBuilder
    private func serverStoppedView(connection: Connection) -> some View {
        ContentUnavailableView {
            Label("Server Not Running", systemImage: "server.rack")
        } description: {
            Text("The local PocketBase server needs to be started.")
        } actions: {
            Button {
                Task {
                    hasAttemptedAutoStart = true
                    await serverManager?.start()
                }
            } label: {
                Label("Start Server", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .task {
            // Auto-start the server for local connections, but only once
            guard !hasAttemptedAutoStart else { return }
            hasAttemptedAutoStart = true
            await serverManager?.start()
        }
    }

    @ViewBuilder
    private func downloadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Downloading PocketBase...")
                .font(.headline)

            Text("This may take a moment")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private func serverErrorView(message: String, connection: Connection) -> some View {
        ContentUnavailableView {
            Label("Server Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task {
                    // Reset flag so we can try again
                    hasAttemptedAutoStart = true
                    await serverManager?.start()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    #endif

    @ViewBuilder
    private func remoteConnectionContent(for connection: Connection) -> some View {
        if isConnecting {
            connectingView(for: connection)
        } else if let error = connectionError {
            errorView(error: error, connection: connection)
        } else if needsSetup, let pocketbase {
            SuperuserSetupView(pocketbase: pocketbase) {
                needsSetup = false
                isCheckingAuth = true
                Task {
                    await checkAuthentication()
                }
            }
        } else if let pocketbase {
            authenticatedContent(pocketbase: pocketbase, connection: connection)
        } else {
            Text("Unable to connect")
        }
    }

    @ViewBuilder
    private func authenticatedContent(pocketbase: PocketBase, connection: Connection) -> some View {
        if isCheckingAuth {
            ProgressView("Checking authentication...")
        } else if isAuthenticated {
            ContentView(
                onLogout: logout,
                onSwitchConnection: onSwitchConnection,
                connectionName: connection.name
            )
            .pocketbase(pocketbase)
        } else {
            AdminLoginView {
                isAuthenticated = true
            }
            .pocketbase(pocketbase)
        }
    }

    @ViewBuilder
    private var noConnectionView: some View {
        ContentUnavailableView {
            Label("No Connection Selected", systemImage: "externaldrive.badge.questionmark")
        } description: {
            Text("Select a connection from the Connections window or add a new one.")
        } actions: {
            Button {
                #if os(macOS)
                NSApp.sendAction(Selector(("showConnectionsWindow:")), to: nil, from: nil)
                #endif
            } label: {
                Text("Open Connections")
            }
        }
    }

    @ViewBuilder
    private func connectingView(for connection: Connection) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Connecting to \(connection.name)...")
                .font(.headline)

            Text(connection.displayURL)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            await connect(to: connection)
        }
    }

    @ViewBuilder
    private func errorView(error: String, connection: Connection) -> some View {
        ContentUnavailableView {
            Label("Connection Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") {
                connectionError = nil
                isConnecting = true
            }
        }
    }

    // MARK: - Connection Logic

    private func connect(to connection: Connection) async {
        do {
            let pb = try await hub.connect(to: connection)
            self.pocketbase = pb

            // Check if instance needs initial setup
            let needsInitialSetup = await checkNeedsSetup(pb)
            if needsInitialSetup {
                self.needsSetup = true
            }

            isConnecting = false
            await checkAuthentication()
        } catch {
            connectionError = error.localizedDescription
            isConnecting = false
        }
    }

    private func checkNeedsSetup(_ pocketbase: PocketBase) async -> Bool {
        // Check if there are any superusers by trying to get auth methods
        // If the instance has no admins, we need to create one
        do {
            // Try to list superusers - this will fail if none exist or if we're not authenticated
            // But we can check the health endpoint or try a specific check
            let collection = pocketbase.collection(Superuser.self)

            // Try to get auth methods - if this returns and has password enabled,
            // but we can't authenticate, we need to check if any admins exist
            _ = try await collection.listAuthMethods()

            // If we got here, the collection exists and is accessible
            // Now check if there are any records
            let result = try await collection.list(page: 1, perPage: 1)
            return result.totalItems == 0
        } catch {
            // If we get a specific error indicating no admins, return true
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("no superuser") ||
               errorString.contains("empty auth collection") ||
               errorString.contains("missing collection") {
                return true
            }
            // For other errors (like 401 unauthorized), assume setup is not needed
            // The user will just need to log in
            return false
        }
    }

    private func checkAuthentication() async {
        // Small delay to let authStore initialize
        try? await Task.sleep(for: .milliseconds(100))

        guard let pocketbase else {
            isAuthenticated = false
            isCheckingAuth = false
            return
        }

        // Validate the token by attempting to refresh it
        // If invalid, it will be automatically cleared
        do {
            let collection = pocketbase.collection(Superuser.self)
            _ = try await collection.authRefresh()
            isAuthenticated = true
        } catch {
            // Token is invalid, clear it
            pocketbase.authStore.clear()
            isAuthenticated = false
        }
        isCheckingAuth = false
    }

    private func logout() {
        pocketbase?.authStore.clear()
        if let connectionID, let connection = hub.connections.first(where: { $0.id == connectionID }) {
            try? hub.logout(from: connection)
        }
        isAuthenticated = false
    }
}

// MARK: - Local Superuser Setup View

#if os(macOS)
/// Setup view for creating the initial superuser on a local PocketBase instance
/// Uses the CLI to create the superuser before the server starts
struct LocalSuperuserSetupView: View {
    let serverManager: PocketBaseServerManager
    let onComplete: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Create Admin Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Set up your PocketBase superuser account to get started.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password (min 10 characters)", text: $password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 350)

            // Validation messages
            VStack(spacing: 8) {
                if !email.isEmpty && !isValidEmail(email) {
                    Label("Please enter a valid email address", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !password.isEmpty && password.count < 10 {
                    Label("Password must be at least 10 characters", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !confirmPassword.isEmpty && password != confirmPassword {
                    Label("Passwords do not match", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let error {
                    Label(error, systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Create button
            Button {
                createAccount()
            } label: {
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Create Account & Start Server")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isFormValid || isCreating)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isFormValid: Bool {
        isValidEmail(email) &&
        password.count >= 10 &&
        password == confirmPassword
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func createAccount() {
        isCreating = true
        error = nil

        Task {
            do {
                try await serverManager.createSuperuser(email: email, password: password)
                onComplete()
            } catch {
                self.error = error.localizedDescription
            }
            isCreating = false
        }
    }
}
#endif

// MARK: - Previews

#Preview {
    ConnectionWindow(connectionID: nil)
        .environment(ConnectionHub())
}
