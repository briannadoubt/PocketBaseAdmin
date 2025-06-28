//
//  SettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 3/26/25.
//

import SwiftUI

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

struct ApplicationSettingsView: View {
    @State private var applicationName: String = ""
    @State private var applicationURL: String = ""
    @State private var hideCollectionCreateAndEditControls = false
    var body: some View {
        ScrollView {
            Form {
                Section {
                    TextField("Application name", text: $applicationName)
                    TextField("Application URL", text: $applicationURL)
                }
                Section {
                    Toggle("Hide collection create and edit controls", isOn: $hideCollectionCreateAndEditControls)
                }
            }
        }
        .navigationTitle("Application")
        .safeAreaInset(edge: .bottom) {
            Button("Save changes") {
                
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
        }
    }
}

struct MailSettingsView: View {
    @State private var senderName = ""
    @State private var senderAddress = ""
    
    @State private var useSMTPMailServer = false
    
    var body: some View {
        ScrollView {
            Form {
                Text("Configure common settings for sending emails.")
                Section {
                    TextField("Sender name", text: $senderName)
                    TextField("Sender address", text: $senderAddress)
                }
                Section {
                    MailTemplate(title: "Verification")
                    MailTemplate(title: "Password reset")
                    MailTemplate(title: "Confirm email change")
                }
                Section {
                    Toggle("Use SMTP mail server **(reccomended)**", isOn: $useSMTPMailServer)
                }
            }
        }
        .navigationTitle("Mail settings")
        .safeAreaInset(edge: .bottom) {
            Button("Send test email") {
                
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
        }
    }
}

struct MailTemplate: View {
    var title: LocalizedStringKey
    
    @State private var subject: String = ""
    @State private var actionURL: String = ""
    @State private var bodyText: String = ""
    
    var body: some View {
        DisclosureGroup {
            Section {
                TextField("Subject", text: $subject)
            } footer: {
                Text("Available placeholder parameters: {APP_NAME}, {APP_URL}.")
                // TODO: Make variables clickable / add them to the keyboard suggestions somehow.
            }
            Section {
                TextField("Action URL", text: $actionURL)
            } footer: {
                Text("Available placeholder parameters: {APP_NAME}, {APP_URL}, {TOKEN}.")
                // TODO: Make variables clickable / add them to the keyboard suggestions somehow.
            }
            Section {
                TextEditor(text: $bodyText)
                    .monospaced()
            } footer: {
                Text("Available placeholder parameters: {APP_NAME}, {APP_URL}, {TOKEN}, {ACTION_URL}.")
                // TODO: Make variables clickable / add them to the keyboard suggestions somehow.
            }
        } label: {
            Label {
                Text("Default \"\(title)\" email template")
            } icon: {
                Image(.template)
            }
        }
    }
}

struct FilesSettingsView: View {
    @State private var useS3Storage = false
    
    @State private var endpoint = ""
    @State private var bucket = ""
    @State private var region = ""
    @State private var accessKey = ""
    @State private var secret = ""
    
    @State private var forcePathStyleAddressing = false
    
    var body: some View {
        ScrollView {
            Form {
                Text("By default PocketBase uses the local file system to store uploaded files.")
                    .listRowSeparator(.hidden)
                Text("If you have limited disk space, you could optionally connect to an S3 compatible storage.")
                    .listRowSeparator(.hidden)
                Section {
                    Toggle("Use S3 storage", isOn: $useS3Storage)
                }
                if useS3Storage {
                    Section {
                        HStack {
                            Text("If you have existing uploaded files, you'll have to migrate them manually from the local file system to the S3 storage.")
                            Text("There are numerous command line tools that can help you, such as: [rclone](https://github.com/rclone/rclone), [s5cmd](https://github.com/peak/s5cmd), etc.")
                        }
                        .listRowBackground(Color.orange)
                    }
                    Section {
                        TextField("Endpoint", text: $endpoint)
                        TextField("Bucket", text: $bucket)
                        TextField("Region", text: $region)
                        TextField("Access key", text: $accessKey)
                        TextField("Secret", text: $secret)
                    }
                    Section {
                        Toggle(isOn: $forcePathStyleAddressing) {
                            Text("Force path-style addressing")
                        }
                    }
                }
            }
        }
        .navigationTitle("Files storage")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Reset") {
                    
                }
                Button("Save") {
                    
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
            }
        }
    }
}

struct BackupsView: View {
    var body: some View {
        ScrollView {
            Form {
                Text("Backups")
            }
        }
        .navigationTitle("Backups")
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

struct ImportCollectionsView: View {
    var body: some View {
        ScrollView {
            Form {
                Text("Import collections")
            }
        }
        .navigationTitle("Import collections")
    }
}

struct AuthProvidersView: View {
    var body: some View {
        ScrollView {
            Form {
                Text("Auth providers")
            }
        }
        .navigationTitle("Auth providers")
    }
}

struct TokenOptionsView: View {
    var body: some View {
        ScrollView {
            Form {
                Text("Token options")
            }
        }
        .navigationTitle("Token options")
    }
}

struct AdminsView: View {
    var body: some View {
        ScrollView {
            Form {
                Text("Admins")
            }
        }
        .navigationTitle("Admins")
    }
}
