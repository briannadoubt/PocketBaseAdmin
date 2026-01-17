//
//  ConnectionWindow.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseUI

/// Window content for a specific PocketBase connection
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct ConnectionWindow: View {
    let connectionID: UUID?

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
        // Access server manager state at top level to establish observation
        #if os(macOS)
        let _ = serverManager?.state
        #endif

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
            let currentState = serverManager.state
            let _ = print("[ConnectionWindow] Rendering for state: \(currentState.displayName)")
            switch currentState {
            case .stopped:
                serverStoppedView(connection: connection)
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
            #if os(macOS)
            ConsoleContainerView(onLogout: logout)
                .pocketbase(pocketbase)
            #else
            ContentView(onLogout: logout)
                .pocketbase(pocketbase)
            #endif
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
        // For now, we determine if setup is needed by checking if auth fails
        // A fresh PocketBase instance will return a specific error when no admin exists
        // In the future, this could be enhanced to check a specific endpoint
        return false
    }

    private func checkAuthentication() async {
        // Small delay to let authStore initialize
        try? await Task.sleep(for: .milliseconds(100))
        isAuthenticated = pocketbase?.authStore.isValid ?? false
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

// MARK: - Previews

#if DEBUG
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
#Preview {
    ConnectionWindow(connectionID: nil)
        .environment(ConnectionHub())
}
#endif
