//
//  SettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

enum SettingsScreen: String {
    case application
    case mail
    case files
    case backups
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
    var body: some View {
        ScrollView {
            Form {
                Text("Export collections")
            }
        }
        .navigationTitle("Export collections")
    }
}
