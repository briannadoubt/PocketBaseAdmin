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

struct ContentView: View {
    @State private var collectionsState = CollectionsState()
    
    @Environment(\.pocketbase) private var pocketbase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @AppStorage("io.pocketbase.admin.tabCustomization") var tabCustomization = TabViewCustomization()
    
    @State private var selectedTab: String?
    
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
                    ForEach(collectionsState.collections) { state in
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
            }
            
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
        .task {
            await collectionsState.load(from: pocketbase)
        }
        .environment(collectionsState)
    }
}

#Preview {
    ContentView()
}
