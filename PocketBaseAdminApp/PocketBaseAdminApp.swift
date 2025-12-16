//
//  PocketBaseAdminApp.swift
//  PocketBaseAdmin
//
//  Created by Brianna Zamora on 3/16/25.
//

import SwiftUI
import PocketBaseUI
import PocketBase
import PocketBaseAdmin
#if canImport(PocketBaseIntents)
import PocketBaseIntents
#endif

@main
struct PocketBaseAdminApp: App {
    init() {
        // Register background tasks for health checks and notifications
        #if !os(macOS)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        #endif
    }

    var body: some Scene {
        WindowGroup("PocketBase Admin", id: "main") {
            AdminRootView()
#if targetEnvironment(simulator) || os(macOS)
                .pocketbase(.localhost)
#elseif DEBUG
                .pocketbase(.localNetwork(ip: "10.0.0.185"))
#else
                .pocketbase(url: URL(string: "https://api.pocketbase.app")!)
#endif
        }
#if os(macOS)
        .defaultSize(width: 1200, height: 800)
#endif
        .commands {
            AppCommands()
            InspectorCommands()
            SidebarCommands()
            ToolbarCommands()
            TextEditingCommands()
            TextFormattingCommands()
        }
    }
}

/// Root view that handles admin authentication state
struct AdminRootView: View {
    @Environment(\.pocketbase) private var pocketbase
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView("Checking authentication...")
            } else if isAuthenticated {
                ContentView(onLogout: logout)
            } else {
                AdminLoginView {
                    isAuthenticated = true
                }
            }
        }
        .task {
            await checkAuthentication()
        }
    }

    private func checkAuthentication() async {
        // Small delay to let authStore initialize
        try? await Task.sleep(for: .milliseconds(100))
        isAuthenticated = pocketbase.authStore.isValid
        isCheckingAuth = false

        // Sync configuration for App Intents (Siri, Shortcuts, Widgets)
        await syncIntentConfiguration()

        // Request notification permissions when authenticated
        if isAuthenticated {
            await BackgroundTaskManager.shared.requestNotificationPermissions()
        }
    }

    private func logout() {
        pocketbase.authStore.clear()
        isAuthenticated = false
    }

    private func syncIntentConfiguration() async {
        #if canImport(PocketBaseIntents)
        await ServerConfiguration.shared.syncFromPocketBase(pocketbase)
        #endif
    }
}
