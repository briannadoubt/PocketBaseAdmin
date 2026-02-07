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
    #if os(macOS)
    @State private var serverManager = PocketBaseServerManager()
    #endif

    /// Central connection hub for managing multiple PocketBase connections
    @State private var connectionHub = ConnectionHub()

    init() {
        // Register background tasks for health checks and notifications
        #if !os(macOS)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        #endif
    }

    var body: some Scene {
        mainWindowScene
        #if os(macOS)
        connectionsWindowScene
        #endif
    }

    @SceneBuilder
    private var mainWindowScene: some Scene {
        WindowGroup("PocketBase Admin", id: "main") {
            #if os(macOS)
            MainWindowContent(connectionHub: connectionHub, serverManager: serverManager)
            #else
            MainWindowContent(connectionHub: connectionHub)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
        .commands {
            appCommands
        }

#if os(macOS)
        Settings {
            SettingsWindowView()
                .pocketbase(.localhost)
        }
#endif
    }

    #if os(macOS)
    @SceneBuilder
    private var connectionsWindowScene: some Scene {
        Window("Connections", id: "connections") {
            ConnectionPickerView()
                .environment(connectionHub)
        }
        .keyboardShortcut("1", modifiers: [.command, .shift])
        .defaultSize(width: 400, height: 500)
    }
    #endif

    @CommandsBuilder
    private var appCommands: some Commands {
        AppCommands()
        #if os(macOS)
        ServerCommands()
        ConnectionCommands()
        #endif
        InspectorCommands()
        SidebarCommands()
        ToolbarCommands()
        TextEditingCommands()
        TextFormattingCommands()
    }
}

// MARK: - Connection Commands (macOS)

#if os(macOS)
struct ConnectionCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            // REMOVED: New Connection Window - no WindowGroup for per-connection windows
            // Button("New Connection Window") {
            //     openWindow(value: UUID?.none)
            // }
            // .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Show Connections") {
                openWindow(id: "connections")
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])
        }
    }
}
#endif

// MARK: - Main Window Content

/// Main window content
struct MainWindowContent: View {
    let connectionHub: ConnectionHub
    #if os(macOS)
    let serverManager: PocketBaseServerManager
    #endif

    var body: some View {
        #if os(macOS)
        NewArchitectureRootView(hub: connectionHub, serverManager: serverManager)
        #else
        NewArchitectureRootView(hub: connectionHub)
        #endif
    }
}

/// Root view for the new multi-connection architecture
/// Uses ConnectionWindow directly without NavigationSplitView wrapper to avoid double sidebars
struct NewArchitectureRootView: View {
    let hub: ConnectionHub
    #if os(macOS)
    let serverManager: PocketBaseServerManager
    #endif

    @State private var selectedConnectionID: UUID?
    @State private var showingConnectionPicker = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        mainContent
        #if os(macOS)
            .environment(\.serverManager, serverManager)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ConnectionPicker(hub: hub, selectedConnectionID: $selectedConnectionID)
                }
            }
        #else
            .sheet(isPresented: $showingConnectionPicker) {
                ConnectionPickerView(selectedConnectionID: $selectedConnectionID)
                    .environment(hub)
            }
        #endif
    }

    private var mainContent: some View {
        Group {
            if let connectionID = selectedConnectionID {
                ConnectionWindow(connectionID: connectionID, onSwitchConnection: switchConnectionAction)
                    .id(connectionID) // Force recreation when connection changes
            } else if let firstConnection = hub.connections.first {
                ConnectionWindow(connectionID: firstConnection.id, onSwitchConnection: switchConnectionAction)
                    .id(firstConnection.id) // Force recreation when connection changes
                    .onAppear {
                        selectedConnectionID = firstConnection.id
                    }
            } else {
                noConnectionsView
            }
        }
        .environment(hub)
        .task {
            // Start Bonjour discovery
            hub.startBonjourBrowsing()

            if selectedConnectionID == nil {
                if let first = hub.connections.first {
                    selectedConnectionID = first.id
                }
                // Don't auto-create localhost on iOS - wait for discovery or manual add
            }
        }
    }

    private var selectedConnection: Connection? {
        hub.connections.first { $0.id == selectedConnectionID }
    }

    private var switchConnectionAction: (() -> Void) {
        #if os(macOS)
        return {
            openWindow(id: "connections")
        }
        #else
        return { [self] in
            showingConnectionPicker = true
        }
        #endif
    }

    private var noConnectionsView: some View {
        ContentUnavailableView {
            Label("No Connections", systemImage: "externaldrive.badge.plus")
        } description: {
            Text("Searching for PocketBase instances on your network...")
        } actions: {
            if !hub.discoveredInstances.isEmpty {
                ForEach(hub.discoveredInstances) { instance in
                    Button(instance.name) {
                        Task {
                            try? await hub.addDiscoveredInstance(instance)
                            if let added = hub.connections.last {
                                selectedConnectionID = added.id
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
                    .padding(.bottom, 8)
            }

            Button("Add Manually") {
                showingConnectionPicker = true
            }

            #if os(macOS)
            Button("Add Local Server") {
                Task {
                    let localhost = Connection.localhost()
                    try? await hub.add(localhost)
                    selectedConnectionID = localhost.id
                }
            }
            #endif
        }
    }
}

#if os(macOS)
/// Toolbar picker for switching between connections
struct ConnectionPicker: View {
    let hub: ConnectionHub
    @Binding var selectedConnectionID: UUID?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Menu {
            ForEach(hub.connections) { connection in
                Button {
                    selectedConnectionID = connection.id
                } label: {
                    HStack {
                        if connection.id == selectedConnectionID {
                            Image(systemName: "checkmark")
                        }
                        Label(connection.name, systemImage: connection.statusIcon)
                    }
                }
            }

            Divider()

            Button {
                openWindow(id: "connections")
            } label: {
                Label("Manage Connections...", systemImage: "slider.horizontal.3")
            }
        } label: {
            Label(
                selectedConnection?.name ?? "Select Connection",
                systemImage: selectedConnection?.statusIcon ?? "externaldrive"
            )
        }
    }

    private var selectedConnection: Connection? {
        hub.connections.first { $0.id == selectedConnectionID }
    }
}
#endif

