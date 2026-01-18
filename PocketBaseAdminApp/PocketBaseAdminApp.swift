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
                ConnectionPickerSheet(hub: hub, selectedConnectionID: $selectedConnectionID)
            }
        #endif
    }

    private var mainContent: some View {
        Group {
            if let connectionID = selectedConnectionID {
                ConnectionWindow(connectionID: connectionID, onSwitchConnection: switchConnectionAction)
            } else if let firstConnection = hub.connections.first {
                ConnectionWindow(connectionID: firstConnection.id, onSwitchConnection: switchConnectionAction)
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

/// Connection picker sheet for iOS
#if !os(macOS)
struct ConnectionPickerSheet: View {
    let hub: ConnectionHub
    @Binding var selectedConnectionID: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingManually = false
    @State private var manualHost = ""
    @State private var manualPort = "8090"
    @State private var manualName = ""
    @State private var useTLS = false

    var body: some View {
        NavigationStack {
            List {
                // Saved connections
                if !hub.connections.isEmpty {
                    Section("Saved") {
                        ForEach(hub.connections) { connection in
                            Button {
                                selectedConnectionID = connection.id
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: connection.statusIcon)
                                        .foregroundStyle(connection.id == selectedConnectionID ? .green : .secondary)

                                    VStack(alignment: .leading) {
                                        Text(connection.name)
                                            .foregroundStyle(.primary)
                                        Text(connection.displayURL)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if connection.id == selectedConnectionID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    try? await hub.remove(hub.connections[index])
                                }
                            }
                        }
                    }
                }

                // Discovered instances
                if !hub.discoveredInstances.isEmpty {
                    Section("Discovered on Network") {
                        ForEach(hub.discoveredInstances) { instance in
                            Button {
                                Task {
                                    try? await hub.addDiscoveredInstance(instance)
                                    if let added = hub.connections.last {
                                        selectedConnectionID = added.id
                                    }
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "bonjour")
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading) {
                                        Text(instance.name)
                                            .foregroundStyle(.primary)
                                        Text("\(instance.host):\(instance.port)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Add manually
                Section("Add Connection") {
                    TextField("Name", text: $manualName)
                    TextField("Host (e.g. 192.168.1.100)", text: $manualHost)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("Port", text: $manualPort)
                        .keyboardType(.numberPad)
                    Toggle("Use HTTPS", isOn: $useTLS)

                    Button("Add") {
                        addManualConnection()
                    }
                    .disabled(manualHost.isEmpty)
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addManualConnection() {
        let port = Int(manualPort) ?? 8090
        let name = manualName.isEmpty ? manualHost : manualName
        let connection = Connection(
            id: UUID(),
            name: name,
            host: manualHost,
            port: port,
            useTLS: useTLS,
            isLocal: false,
            discoveredViaBonjour: false
        )
        Task {
            try? await hub.add(connection)
            selectedConnectionID = connection.id
            dismiss()
        }
    }
}
#endif

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

