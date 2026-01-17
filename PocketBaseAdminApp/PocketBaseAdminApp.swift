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
    @State private var serverManager: AnyObject? = {
        if #available(macOS 15.0, *) {
            return PocketBaseServerManager()
        }
        return nil
    }()
    #endif

    /// Central connection hub for managing multiple PocketBase connections
    @State private var connectionHub: AnyObject? = {
        if #available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *) {
            return ConnectionHub()
        }
        return nil
    }()

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
            MainWindowContent(connectionHub: connectionHub, serverManager: serverManager)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
        .commands {
            appCommands
        }
    }

    #if os(macOS)
    @available(macOS 15.0, *)
    @SceneBuilder
    private var connectionsWindowScene: some Scene {
        Window("Connections", id: "connections") {
            if let hub = connectionHub as? ConnectionHub {
                ConnectionPickerView()
                    .environment(hub)
            }
        }
        .keyboardShortcut("1", modifiers: [.command, .shift])
        .defaultSize(width: 400, height: 500)
    }
    #endif

    @CommandsBuilder
    private var appCommands: some Commands {
        AppCommands()
        #if os(macOS)
        if #available(macOS 15.0, *) {
            ServerCommands()
            ConnectionCommands()
        }
        #endif
        InspectorCommands()
        SidebarCommands()
        ToolbarCommands()
        TextEditingCommands()
        TextFormattingCommands()
    }
}

// MARK: - Connection Hub Modifier

@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct ConnectionHubModifier: ViewModifier {
    let connectionHub: AnyObject?

    func body(content: Content) -> some View {
        if let hub = connectionHub as? ConnectionHub {
            content.environment(hub)
        } else {
            content
        }
    }
}

#if os(macOS)
/// View modifier to inject server manager into environment
/// Uses a wrapper view to ensure @Observable tracking works correctly
struct ServerManagerModifier: ViewModifier {
    let serverManager: AnyObject?

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *), let manager = serverManager as? PocketBaseServerManager {
            ServerManagerObservingView(manager: manager) {
                content
            }
        } else {
            content
        }
    }
}

/// Wrapper view that properly observes the server manager
/// This is needed because storing @Observable objects as AnyObject breaks observation
@available(macOS 15.0, *)
struct ServerManagerObservingView<Content: View>: View {
    @Bindable var manager: PocketBaseServerManager
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Access state to establish observation, then pass manager through environment
        let _ = manager.state
        content()
            .environment(\.serverManager, manager)
    }
}
#endif

// MARK: - Connection Commands (macOS)

#if os(macOS)
@available(macOS 15.0, *)
struct ConnectionCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Connection Window") {
                openWindow(value: UUID?.none)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Show Connections") {
                openWindow(id: "connections")
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])
        }
    }
}
#endif

// MARK: - Main Window Content

/// Main window content that handles availability checks and routing
struct MainWindowContent: View {
    let connectionHub: AnyObject?
    let serverManager: AnyObject?

    var body: some View {
        if #available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *),
           let hub = connectionHub as? ConnectionHub {
            // New multi-connection architecture
            NewArchitectureRootView(hub: hub, serverManager: serverManager)
        } else {
            // Legacy single-connection mode
            LegacyRootView(serverManager: serverManager)
        }
    }
}

/// Root view for the new multi-connection architecture
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct NewArchitectureRootView: View {
    let hub: ConnectionHub
    let serverManager: AnyObject?

    @State private var selectedConnectionID: UUID?
    @State private var showingConnectionPicker = true

    var body: some View {
        NavigationSplitView {
            // Sidebar with connections list
            ConnectionSidebar(selectedConnectionID: $selectedConnectionID)
        } detail: {
            // Main content area
            if let connectionID = selectedConnectionID {
                ConnectionWindow(connectionID: connectionID)
            } else {
                selectConnectionView
            }
        }
        .environment(hub)
        #if os(macOS)
        .modifier(ServerManagerModifier(serverManager: serverManager))
        #endif
    }

    private var selectConnectionView: some View {
        ContentUnavailableView {
            Label("Select a Connection", systemImage: "externaldrive.connected.to.line.below")
        } description: {
            Text("Choose a PocketBase instance from the sidebar, or add a new one.")
        }
    }
}

/// Sidebar view showing all connections
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct ConnectionSidebar: View {
    @Binding var selectedConnectionID: UUID?
    @Environment(ConnectionHub.self) private var hub
    #if os(macOS)
    @Environment(\.serverManager) private var serverManager
    #endif

    @State private var isAddingConnection = false

    var body: some View {
        List(selection: $selectedConnectionID) {
            // Local server section
            Section("Local Server") {
                ForEach(hub.connections.filter { $0.isLocal }) { connection in
                    ConnectionSidebarRow(connection: connection)
                        .tag(connection.id)
                }

                if hub.connections.filter({ $0.isLocal }).isEmpty {
                    Button {
                        addLocalConnection()
                    } label: {
                        Label("Add Local Server", systemImage: "plus")
                    }
                }
            }

            // Remote connections section
            Section("Remote Servers") {
                ForEach(hub.connections.filter { !$0.isLocal }) { connection in
                    ConnectionSidebarRow(connection: connection)
                        .tag(connection.id)
                }
            }

            // Discovered on network
            if !hub.discoveredInstances.isEmpty {
                Section("Discovered") {
                    ForEach(hub.discoveredInstances) { instance in
                        Button {
                            addDiscoveredInstance(instance)
                        } label: {
                            Label(instance.name, systemImage: "bonjour")
                        }
                    }
                }
            }
        }
        .navigationTitle("Connections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingConnection = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingConnection) {
            AddConnectionView()
        }
        .onAppear {
            hub.startBonjourBrowsing()
        }
    }

    private func addLocalConnection() {
        Task {
            let connection = Connection.localhost()
            try? await hub.add(connection)
            selectedConnectionID = connection.id
        }
    }

    private func addDiscoveredInstance(_ instance: BonjourBrowser.DiscoveredInstance) {
        Task {
            try? await hub.addDiscoveredInstance(instance)
        }
    }
}

/// Row in the connection sidebar
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct ConnectionSidebarRow: View {
    let connection: Connection
    @Environment(ConnectionHub.self) private var hub
    #if os(macOS)
    @Environment(\.serverManager) private var serverManager
    #endif

    var body: some View {
        HStack {
            Image(systemName: connection.statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading) {
                Text(connection.name)
                    .fontWeight(.medium)

                #if os(macOS)
                if connection.isLocal, let serverManager {
                    Text(serverManager.state.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(connection.displayURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #else
                Text(connection.displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            Spacer()

            if hub.isAuthenticated(for: connection) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    try? await hub.remove(connection)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statusColor: Color {
        #if os(macOS)
        if connection.isLocal, let serverManager {
            return serverManager.state.isRunning ? .green : .secondary
        }
        #endif
        if connection.isLocal {
            return .blue
        } else if connection.discoveredViaBonjour {
            return .orange
        }
        return .secondary
    }
}

/// Legacy root view for older OS versions
struct LegacyRootView: View {
    let serverManager: AnyObject?

    var body: some View {
        AdminRootView()
            #if targetEnvironment(simulator) || os(macOS)
            .pocketbase(.localhost)
            #elseif DEBUG
            .pocketbase(.localNetwork(ip: "10.0.0.185"))
            #else
            .pocketbase(url: URL(string: "https://api.pocketbase.app")!)
            #endif
            #if os(macOS)
            .modifier(ServerManagerModifier(serverManager: serverManager))
            #endif
    }
}

// MARK: - Legacy Root View

/// Root view that handles admin authentication state (for older OS versions)
struct AdminRootView: View {
    @Environment(\.pocketbase) private var pocketbase
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                ProgressView("Checking authentication...")
            } else if isAuthenticated {
                #if os(macOS)
                if #available(macOS 15.0, *) {
                    ConsoleContainerView(onLogout: logout)
                } else {
                    ContentView(onLogout: logout)
                }
                #else
                ContentView(onLogout: logout)
                #endif
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
