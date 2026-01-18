//
//  SettingsWindowView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 12/19/25.
//

#if os(macOS)
import SwiftUI
import PocketBase
import PocketBaseAdmin
import OSLog

private let logger = Logger(subsystem: "PocketBaseAdminApp", category: "SettingsWindowView")

struct SettingsWindowView: View {
    @State private var settings = Admin.Settings()
    @State private var selection: SettingsScreen? = .application
    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("System") {
                    Label(SettingsScreen.application.title, systemImage: SettingsScreen.application.systemImage)
                        .tag(SettingsScreen.application)
                    Label(SettingsScreen.mail.title, systemImage: SettingsScreen.mail.systemImage)
                        .tag(SettingsScreen.mail)
                    Label(SettingsScreen.files.title, systemImage: SettingsScreen.files.systemImage)
                        .tag(SettingsScreen.files)
                    Label(SettingsScreen.backups.title, systemImage: SettingsScreen.backups.systemImage)
                        .tag(SettingsScreen.backups)
                    Label(SettingsScreen.health.title, systemImage: SettingsScreen.health.systemImage)
                        .tag(SettingsScreen.health)
                }

                Section("Sync") {
                    Label(SettingsScreen.exportCollections.title, systemImage: SettingsScreen.exportCollections.systemImage)
                        .tag(SettingsScreen.exportCollections)
                    Label(SettingsScreen.importCollections.title, systemImage: SettingsScreen.importCollections.systemImage)
                        .tag(SettingsScreen.importCollections)
                }

                Section("Authentication") {
                    Label(SettingsScreen.authProviders.title, systemImage: SettingsScreen.authProviders.systemImage)
                        .tag(SettingsScreen.authProviders)
                    Label(SettingsScreen.tokenOptions.title, systemImage: SettingsScreen.tokenOptions.systemImage)
                        .tag(SettingsScreen.tokenOptions)
                    Label(SettingsScreen.admins.title, systemImage: SettingsScreen.admins.systemImage)
                        .tag(SettingsScreen.admins)
                }
            }
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
            .toolbar(.hidden, for: .windowToolbar)
        } detail: {
            Group {
                switch selection {
                case .application:
                    ApplicationSettingsView()
                case .mail:
                    MailSettingsView()
                case .files:
                    FilesSettingsView()
                case .backups:
                    BackupsView()
                case .health:
                    HealthDashboardView()
                case .exportCollections:
                    ExportCollectionsView()
                case .importCollections:
                    ImportCollectionsView()
                case .authProviders:
                    AuthProvidersView()
                case .tokenOptions:
                    TokenOptionsView()
                case .admins:
                    AdminsView()
                case .none:
                    ContentUnavailableView("Select a Setting", systemImage: "gearshape")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
        .navigationSplitViewStyle(.balanced)
        .task {
            do {
                try await settings.load(pocketbase: pocketbase)
            } catch {
                logger.error("Failed to load settings: \(error.localizedDescription)")
            }
        }
        .environment(settings)
    }
}

#Preview {
    SettingsWindowView()
        .pocketbase(.localhost)
}
#endif
