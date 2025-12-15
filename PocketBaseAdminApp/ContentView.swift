//
//  ContentView.swift
//  PocketBaseAdmin
//
//  Created by Brianna Zamora on 3/16/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

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

struct NavigationGroup: View {
    
    var body: some View {
        
    }
}

struct ContentView: View {
    @State private var collectionsState = CollectionsState()
    @State private var settings = Admin.Settings()

    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("io.pocketbase.admin.tabCustomization.v2") var tabCustomization = TabViewCustomization()

    @State private var selectedTab: String?
    @State private var showNewCollectionSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
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
            } else {
                
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
        .task {
            await collectionsState.load(from: pocketbase)
        }
        .task {
            do {
                try await settings.load(pocketbase: pocketbase)
            } catch {
                print("Failed to load settings: \(error.localizedDescription)")
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
        .environment(collectionsState)
        .environment(settings)
    }
}

#Preview {
    ContentView()
}
