//
//  ContentView.swift
//  PocketBaseAdmin
//
//  Created by Brianna Zamora on 3/16/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin
import OSLog

private let logger = Logger(subsystem: "PocketBaseAdminApp", category: "ContentView")

extension CollectionModelType {
    var image: ImageResource {
        switch self {
        case .base:
            .base
        case .auth:
            .auth
        case .view:
            .view
        }
    }
}

extension EnvironmentValues {
#if canImport(UIKit)
    @Entry var device: UIDevice = .current
#endif
}

struct ContentView: View {
    var onLogout: (() -> Void)?

    @State private var collectionsState = CollectionsState()
    @State private var settings = Admin.Settings()

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Persists user's tab customization preferences (tab order, visibility, etc.)
    /// Version 2: Updated to use new TabSection structure with system/sync/auth groupings
    @AppStorage("io.pocketbase.admin.tabCustomization.v2") var tabCustomization = TabViewCustomization()

    @State private var selectedTab: String?
    @State private var showNewCollectionSheet = false
    @State private var showLogoutConfirmation = false
    @State private var collectionToEdit: CollectionModel?
    @State private var collectionToDelete: CollectionModel?
    @State private var showDeleteConfirmation = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard tab - first for prominence
            Tab(value: AdminTab.dashboard.rawValue) {
                NavigationStack {
                    DashboardView()
                }
            } label: {
                AdminTab.dashboard.label
            }
            #if !os(macOS)
            .customizationBehavior(.disabled, for: .tabBar, .sidebar)
            #endif

            if horizontalSizeClass == .compact {
                Tab(value: AdminTab.collections.rawValue) {
                    NavigationStack {
                        CollectionsList(selection: $selectedTab)
                    }
                } label: {
                    AdminTab.collections.label
                }
#if !os(macOS)
                .customizationBehavior(.disabled, for: .tabBar, .sidebar)
#endif
            } else {
                TabSection {
                    if collectionsState.isLoading && collectionsState.collections.isEmpty {
                        Tab(value: "loading") {
                            ProgressView("Connecting to server...")
                        } label: {
                            Label("Loading...", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                .symbolEffect(.rotate, isActive: true)
                        }
                    }
                    if let error = collectionsState.error {
                        Tab(value: "error") {
                            ContentUnavailableView {
                                Label("Failed to Load Collections", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text(error)
                            } actions: {
                                Button("Retry") {
                                    Task {
                                        await collectionsState.load(from: pocketbase)
                                    }
                                }
                            }
                        } label: {
                            Label("Error", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    } else if !collectionsState.isLoading && collectionsState.userCollections.isEmpty {
                        Tab(value: "no-collections") {
                            ContentUnavailableView {
                                Label("No Collections", systemImage: "folder")
                            } description: {
                                Text("Create your first collection to get started.")
                            } actions: {
                                Button("New Collection") {
                                    showNewCollectionSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } label: {
                            Label("No Collections", systemImage: "folder")
                        }
                    }
                    ForEach(collectionsState.userCollections) { state in
                        Tab(value: state.collection.id) {
                            NavigationStack {
                                CollectionView(state: state)
                            }
                        } label: {
                            Label {
                                Text(state.collection.name)
                            } icon: {
                                Image(state.collection.type.image)
                                    .resizable()
                                    .scaledToFit()
                            }
                            .contextMenu {
                                CollectionMenuContent(
                                    collection: state.collection,
                                    onEdit: {
                                        collectionToEdit = state.collection
                                    },
                                    onDuplicate: {
                                        duplicateCollection(state.collection)
                                    },
                                    onDelete: {
                                        collectionToDelete = state.collection
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .customizationID(state.collection.id)
                        .defaultVisibility(.hidden, for: .tabBar)
                    }

                } header: {
                    AdminTab.collections.label
                }
                #if !os(macOS)
                .customizationBehavior(.disabled, for: .tabBar, .sidebar)
                #endif

                TabSection {
                    ForEach(collectionsState.systemCollections) { state in
                        Tab(value: state.collection.id) {
                            NavigationStack {
                                CollectionView(state: state)
                            }
                        } label: {
                            Label {
                                Text(state.collection.name)
                            } icon: {
                                Image(state.collection.type.image)
                                    .resizable()
                                    .scaledToFit()
                            }
                            .contextMenu {
                                CollectionMenuContent(
                                    collection: state.collection,
                                    onEdit: {
                                        collectionToEdit = state.collection
                                    },
                                    onDuplicate: {
                                        duplicateCollection(state.collection)
                                    },
                                    onDelete: {
                                        collectionToDelete = state.collection
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .customizationID(state.collection.id)
                        .defaultVisibility(.hidden, for: .tabBar)
                    }
                } header: {
                    Label("System Collections", systemImage: "gearshape.2")
                }
                #if !os(macOS)
                .defaultVisibility(.hidden, for: .sidebar)
                .customizationBehavior(.disabled, for: .tabBar, .sidebar)
                #endif
            }
            
            TabSection("Telemetry") {
                Tab(value: AdminTab.logs.rawValue) {
                    NavigationStack {
                        LogsView()
                    }
                } label: {
                    AdminTab.logs.label
                }
                #if !os(macOS)
                .customizationBehavior(.disabled, for: .tabBar, .sidebar)
                #endif
            }
            
            if horizontalSizeClass == .compact {
                Tab(value: AdminTab.settings.rawValue) {
                    NavigationStack {
                        SettingsView(selection: $selectedTab)
                    }
                } label: {
                    AdminTab.settings.label
                }
                #if !os(macOS)
                .customizationBehavior(.disabled, for: .tabBar, .sidebar)
                #endif
            }

#if !os(macOS)
            if horizontalSizeClass != .compact {
                TabSection("System") {
                    Tab(value: SettingsScreen.application.rawValue) {
                        NavigationStack {
                            ApplicationSettingsView()
                        }
                    } label: {
                        SettingsScreen.application.label
                    }
                    .customizationID(SettingsScreen.application.rawValue)

                    Tab(value: SettingsScreen.mail.rawValue) {
                        NavigationStack {
                            MailSettingsView()
                        }
                    } label: {
                        SettingsScreen.mail.label
                    }
                    .customizationID(SettingsScreen.mail.rawValue)

                    Tab(value: SettingsScreen.files.rawValue) {
                        NavigationStack {
                            FilesSettingsView()
                        }
                    } label: {
                        SettingsScreen.files.label
                    }
                    .customizationID(SettingsScreen.files.rawValue)

                    Tab(value: SettingsScreen.backups.rawValue) {
                        NavigationStack {
                            BackupsView()
                        }
                    } label: {
                        SettingsScreen.backups.label
                    }
                    .customizationID(SettingsScreen.backups.rawValue)

                    Tab(value: SettingsScreen.health.rawValue) {
                        NavigationStack {
                            HealthDashboardView()
                        }
                    } label: {
                        SettingsScreen.health.label
                    }
                    .customizationID(SettingsScreen.health.rawValue)
                }
                .customizationID("System")

                TabSection("Sync") {
                    Tab(value: SettingsScreen.exportCollections.rawValue) {
                        NavigationStack {
                            ExportCollectionsView()
                        }
                    } label: {
                        SettingsScreen.exportCollections.label
                    }
                    .customizationID(SettingsScreen.exportCollections.rawValue)

                    Tab(value: SettingsScreen.importCollections.rawValue) {
                        NavigationStack {
                            ImportCollectionsView()
                        }
                    } label: {
                        SettingsScreen.importCollections.label
                    }
                    .customizationID(SettingsScreen.importCollections.rawValue)
                }
                .customizationID("Sync")

                TabSection("Authentication") {
                    Tab(value: SettingsScreen.authProviders.rawValue) {
                        NavigationStack {
                            AuthProvidersView()
                        }
                    } label: {
                        SettingsScreen.authProviders.label
                    }
                    .customizationID(SettingsScreen.authProviders.rawValue)

                    Tab(value: SettingsScreen.tokenOptions.rawValue) {
                        NavigationStack {
                            TokenOptionsView()
                        }
                    } label: {
                        SettingsScreen.tokenOptions.label
                    }
                    .customizationID(SettingsScreen.tokenOptions.rawValue)

                    Tab(value: SettingsScreen.admins.rawValue) {
                        NavigationStack {
                            AdminsView()
                        }
                    } label: {
                        SettingsScreen.admins.label
                    }
                    .customizationID(SettingsScreen.admins.rawValue)
                }
                .customizationID("Authentication")
            }
#endif
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabCustomization)
        .tabViewSidebarHeader {
            Button {
                showNewCollectionSheet = true
            } label: {
                Label("New Collection", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
        }
        .tabViewSidebarFooter {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
        }
        .confirmationDialog("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Log Out", role: .destructive) {
                onLogout?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .task {
            await collectionsState.load(from: pocketbase)
        }
        .task {
            do {
                try await settings.load(pocketbase: pocketbase)
            } catch {
                logger.error("Failed to load settings: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showNewCollectionSheet) {
            CollectionEditorView(
                collection: nil,
                onSave: { newCollection in
                    Task {
                        await collectionsState.load(from: pocketbase)
                        selectedTab = newCollection.id
                    }
                }
            )
        }
        .sheet(item: $collectionToEdit) { collection in
            CollectionEditorView(
                collection: collection,
                onSave: { updatedCollection in
                    collectionsState.updateCollection(updatedCollection)
                }
            )
        }
        .alert("Delete Collection?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                collectionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    Task {
                        try? await collectionsState.delete(id: collection.id, using: pocketbase)
                        collectionToDelete = nil
                    }
                }
            }
        } message: {
            if let collection = collectionToDelete {
                Text("Are you sure you want to delete \"\(collection.name)\"? This will permanently delete all records in this collection. This action cannot be undone.")
            }
        }
        .environment(collectionsState)
        .environment(settings)
        .focusedValue(\.collectionsState, collectionsState)
        .focusedValue(\.pocketbase, pocketbase)
        .focusedValue(\.selectedCollection, selectedCollectionModel)
        .onChange(of: collectionsState.authExpired) { _, expired in
            if expired {
                onLogout?()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newCollection)) { _ in
            showNewCollectionSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .refresh)) { _ in
            Task {
                await collectionsState.load(from: pocketbase)
            }
        }
    }

    /// Currently selected collection based on selectedTab
    private var selectedCollectionModel: CollectionModel? {
        collectionsState.collections.first { $0.collection.id == selectedTab }?.collection
    }

    private func duplicateCollection(_ collection: CollectionModel) {
        // Open the collection editor with the collection as a template
        // User will need to change the name since it's a new collection
        collectionToEdit = collection
    }
}

#Preview {
    ContentView()
}
