//
//  ConnectionPickerView.swift
//  PocketBaseAdmin
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// View for picking and managing PocketBase connections
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
struct ConnectionPickerView: View {
    @Environment(ConnectionHub.self) private var hub
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedConnectionID: UUID?

    @State private var isAddingConnection = false
    @State private var searchText = ""

    init(selectedConnectionID: Binding<UUID?> = .constant(nil)) {
        self._selectedConnectionID = selectedConnectionID
    }

    var body: some View {
        NavigationStack {
            connectionList
                .searchable(text: $searchText, prompt: "Search connections")
                .navigationTitle("Connections")
                #if os(macOS)
                .navigationSubtitle("\(hub.connections.count) saved")
                #elseif os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    toolbarContent
                }
                .sheet(isPresented: $isAddingConnection) {
                    AddConnectionView()
                }
        }
        .onAppear {
            hub.startBonjourBrowsing()
        }
        .onDisappear {
            hub.stopBonjourBrowsing()
        }
    }

    // MARK: - Subviews

    private var connectionList: some View {
        List {
            savedConnectionsSection
            discoveredSection
        }
    }

    private var savedConnectionsSection: some View {
        Section {
            ForEach(filteredConnections) { connection in
                Button {
                    openConnection(connection)
                } label: {
                    ConnectionRow(
                        connection: connection,
                        isSelected: connection.id == selectedConnectionID
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    connectionContextMenu(for: connection)
                }
            }
            .onDelete(perform: deleteConnections)
        } header: {
            Label("Saved Connections", systemImage: "externaldrive.connected.to.line.below")
        }
    }

    @ViewBuilder
    private var discoveredSection: some View {
        if !hub.discoveredInstances.isEmpty {
            Section {
                ForEach(hub.discoveredInstances) { instance in
                    Button {
                        addDiscoveredInstance(instance)
                    } label: {
                        DiscoveredInstanceRow(instance: instance)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("Discovered on Network", systemImage: "bonjour")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if !os(macOS)
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") {
                dismiss()
            }
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            Button {
                isAddingConnection = true
            } label: {
                Label("Add Connection", systemImage: "plus")
            }
        }

        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            Button {
                if hub.bonjourBrowser.isSearching {
                    hub.stopBonjourBrowsing()
                } else {
                    hub.startBonjourBrowsing()
                }
            } label: {
                Label(
                    hub.bonjourBrowser.isSearching ? "Stop Scanning" : "Scan Network",
                    systemImage: hub.bonjourBrowser.isSearching ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right"
                )
            }
        }
        #endif
    }

    // MARK: - Computed Properties

    private var filteredConnections: [Connection] {
        if searchText.isEmpty {
            return hub.connections
        }
        return hub.connections.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Actions

    private func openConnection(_ connection: Connection) {
        selectedConnectionID = connection.id
        #if !os(macOS)
        dismiss()
        #endif
    }

    private func deleteConnections(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let connection = filteredConnections[index]
                try? await hub.remove(connection)
            }
        }
    }

    private func addDiscoveredInstance(_ instance: BonjourBrowser.DiscoveredInstance) {
        Task {
            try? await hub.addDiscoveredInstance(instance)
        }
    }

    @ViewBuilder
    private func connectionContextMenu(for connection: Connection) -> some View {
        Button {
            openConnection(connection)
        } label: {
            Label("Open", systemImage: "arrow.up.forward.app")
        }

        // REMOVED: Multi-window support - no WindowGroup defined for per-connection windows
        // The app uses a single main window that switches between connections

        Divider()

        Button(role: .destructive) {
            Task {
                try? await hub.remove(connection)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Connection Row

@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
private struct ConnectionRow: View {
    let connection: Connection
    let isSelected: Bool
    @Environment(ConnectionHub.self) private var hub

    var body: some View {
        HStack {
            Image(systemName: connection.statusIcon)
                .foregroundStyle(isSelected ? Color.accentColor : statusColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.headline)

                Text(connection.displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hub.isAuthenticated(for: connection) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            #if os(macOS)
            if let lastConnected = connection.lastConnected {
                Text(lastConnected, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            #else
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
            #endif
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if connection.isLocal {
            return .blue
        } else if connection.discoveredViaBonjour {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Discovered Instance Row

@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
private struct DiscoveredInstanceRow: View {
    let instance: BonjourBrowser.DiscoveredInstance

    var body: some View {
        HStack {
            Image(systemName: "bonjour")
                .foregroundStyle(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.headline)

                Text("\(instance.host):\(instance.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#if DEBUG
@available(macOS 15.0, iOS 18.0, visionOS 2.0, watchOS 11.0, tvOS 18.0, *)
#Preview {
    ConnectionPickerView()
        .environment(ConnectionHub())
}
#endif
