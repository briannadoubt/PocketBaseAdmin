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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingConnection = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            connectionList
                .searchable(text: $searchText, prompt: "Search connections")
                .navigationTitle("Connections")
                #if os(macOS)
                .navigationSubtitle("\(hub.connections.count) saved")
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
                    ConnectionRow(connection: connection)
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
        #if os(macOS)
        openWindow(value: connection.id)
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

        #if os(macOS)
        Button {
            openWindow(value: connection.id)
        } label: {
            Label("Open in New Window", systemImage: "uiwindow.split.2x1")
        }
        #endif

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
    @Environment(ConnectionHub.self) private var hub

    var body: some View {
        HStack {
            Image(systemName: connection.statusIcon)
                .foregroundStyle(statusColor)
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

            if let lastConnected = connection.lastConnected {
                Text(lastConnected, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
