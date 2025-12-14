//
//  SettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum SettingsScreen: String {
    case application
    case mail
    case files
    case backups
    case health
    case exportCollections
    case importCollections
    case authProviders
    case tokenOptions
    case admins

    var title: LocalizedStringKey {
        switch self {
        case .application:
            "Application"
        case .mail:
            "Mail settings"
        case .files:
            "Files storage"
        case .backups:
            "Backups"
        case .health:
            "Health"
        case .exportCollections:
            "Export collections"
        case .importCollections:
            "Import collections"
        case .authProviders:
            "Auth providers"
        case .tokenOptions:
            "Token options"
        case .admins:
            "Admins"
        }
    }

    var systemImage: String {
        switch self {
        case .application:
            "house"
        case .mail:
            "paperplane"
        case .files:
            "tray.2"
        case .backups:
            "archivebox"
        case .health:
            "heart.text.square"
        case .exportCollections:
            "externaldrive.badge.icloud"
        case .importCollections:
            "externaldrive.badge.plus"
        case .authProviders:
            "lock"
        case .tokenOptions:
            "key.horizontal"
        case .admins:
            "person.badge.shield.checkmark"
        }
    }
    
    @ViewBuilder var label: some View {
        Label(title, systemImage: systemImage)
    }
}

struct SettingsView: View {
    @Binding var selection: String?
    var body: some View {
        List {
            Section("System") {
                NavigationLink {
                    ApplicationSettingsView()
                } label: {
                    SettingsScreen.application.label
                }
                NavigationLink {
                    MailSettingsView()
                } label: {
                    SettingsScreen.mail.label
                }
                NavigationLink {
                    FilesSettingsView()
                } label: {
                    SettingsScreen.files.label
                }
                NavigationLink {
                    BackupsView()
                } label: {
                    SettingsScreen.backups.label
                }
                NavigationLink {
                    HealthDashboardView()
                } label: {
                    SettingsScreen.health.label
                }
            }
            Section("Sync") {
                NavigationLink {
                    ExportCollectionsView()
                } label: {
                    SettingsScreen.exportCollections.label
                }
                NavigationLink {
                    ImportCollectionsView()
                } label: {
                    SettingsScreen.importCollections.label
                }
            }
            Section("Authentication") {
                NavigationLink {
                    AuthProvidersView()
                } label: {
                    SettingsScreen.authProviders.label
                }
                NavigationLink {
                    TokenOptionsView()
                } label: {
                    SettingsScreen.tokenOptions.label
                }
                NavigationLink {
                    AdminsView()
                } label: {
                    SettingsScreen.admins.label
                }
            }
        }
        .navigationTitle("Settings")
    }
}

@propertyWrapper
public struct EnvironmentBound<T: Observable & AnyObject>: DynamicProperty {
    @Environment(T.self) private var environmentObject
    public init(_ type: T.Type = T.self) {}
    public var wrappedValue: T {
        environmentObject
    }
    public var projectedValue: Bindable<T> {
        Bindable(environmentObject)
    }
}

struct ExportCollectionsView: View {
    @State private var collections: [CollectionModel] = []
    @State private var selectedCollections: Set<String> = []
    @State private var isLoading = false
    @State private var exportedJSON = ""
    @State private var showExportSheet = false
    @State private var errorMessage: String?

    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                // Selection controls
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Collection Schemas")
                        .font(.headline)

                    Text("Select collections to export as JSON.")
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Select All") {
                            selectedCollections = Set(collections.map(\.id))
                        }
                        .buttonStyle(.bordered)

                        Button("Deselect All") {
                            selectedCollections.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.05))
                )

                // Collections list
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    VStack(spacing: 0) {
                        ForEach(collections) { collection in
                            CollectionExportRow(
                                collection: collection,
                                isSelected: selectedCollections.contains(collection.id),
                                onToggle: {
                                    if selectedCollections.contains(collection.id) {
                                        selectedCollections.remove(collection.id)
                                    } else {
                                        selectedCollections.insert(collection.id)
                                    }
                                }
                            )

                            if collection.id != collections.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.05))
                            )
                    )
                }

                // Export button
                Button {
                    exportCollections()
                } label: {
                    Text("Export \(selectedCollections.count) Collections")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCollections.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Export Collections")
        .task {
            await loadCollections()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportJSONSheet(json: exportedJSON)
        }
    }

    private func loadCollections() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            collections = try await pocketbase.admin.collections.list().items
            // Auto-select all non-system collections
            selectedCollections = Set(collections.filter { !$0.system }.map(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCollections() {
        let selectedItems = collections.filter { selectedCollections.contains($0.id) }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(selectedItems)
            exportedJSON = String(data: data, encoding: .utf8) ?? "[]"
            showExportSheet = true
        } catch {
            errorMessage = "Failed to encode: \(error.localizedDescription)"
        }
    }
}

struct CollectionExportRow: View {
    let collection: CollectionModel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Image(collection.type.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(collection.name)

                if collection.system {
                    Text("system")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.2))
                        )
                }

                Spacer()

                Text("\(collection.schema?.count ?? 0) fields")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

struct ExportJSONSheet: View {
    let json: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if copied {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Copied to clipboard!")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                        )
                    }

                    Text(json)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .padding()
            }
            .navigationTitle("Exported JSON")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Copy") {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        #else
                        UIPasteboard.general.string = json
                        #endif
                        copied = true
                    }
                }
            }
        }
    }
}
