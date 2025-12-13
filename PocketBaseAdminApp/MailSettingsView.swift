//
//  MailSettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct MailSettingsView: View {
    @State private var senderName = ""
    @State private var senderAddress = ""

    @State private var useSMTPMailServer = false
    @State private var smtpHost = ""
    @State private var smtpPort = ""
    @State private var smtpUsername = ""
    @State private var smtpPassword = ""
    @State private var smtpAuthMethod = "PLAIN"
    @State private var smtpTLS = true
    @State private var smtpLocalName = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @Environment(\.pocketbase) private var pocketbase
    @Environment(Admin.Settings.self) private var settings

    var body: some View {
        ScrollView {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage {
                    Section {
                        Label(successMessage, systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Text("Configure common settings for sending emails.")
                        .foregroundStyle(.secondary)
                }

                Section("Sender Info") {
                    TextField("Sender name", text: $senderName)
                    TextField("Sender address", text: $senderAddress)
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    #endif
                }

                Section {
                    Toggle("Use SMTP mail server (recommended)", isOn: $useSMTPMailServer)
                }

                if useSMTPMailServer {
                    Section("SMTP Configuration") {
                        TextField("Host", text: $smtpHost)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif

                        TextField("Port", text: $smtpPort)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif

                        TextField("Username", text: $smtpUsername)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif

                        SecureField("Password", text: $smtpPassword)

                        Picker("Auth Method", selection: $smtpAuthMethod) {
                            Text("PLAIN").tag("PLAIN")
                            Text("LOGIN").tag("LOGIN")
                        }

                        Toggle("Use TLS", isOn: $smtpTLS)

                        TextField("Local name (optional)", text: $smtpLocalName)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif
                    }
                }
            }
            .safeAreaPadding()
        }
        .navigationTitle("Mail settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveSettings()
                    }
                }
                .disabled(isSaving)
            }
        }
        .task {
            loadSettings()
        }
    }

    private func loadSettings() {
        senderName = settings.meta?.senderName ?? ""
        senderAddress = settings.meta?.senderAddress ?? ""

        if let smtp = settings.smtp {
            useSMTPMailServer = smtp.enabled ?? false
            smtpHost = smtp.host ?? ""
            smtpPort = smtp.port.map { String($0) } ?? ""
            smtpUsername = smtp.username ?? ""
            smtpPassword = smtp.password ?? ""
            smtpAuthMethod = smtp.authMethod ?? "PLAIN"
            smtpTLS = smtp.tls ?? true
            smtpLocalName = smtp.localName ?? ""
        }
    }

    private func saveSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        // Update meta settings
        if settings.meta == nil {
            settings.meta = Meta()
        }
        settings.meta?.senderName = senderName.isEmpty ? nil : senderName
        settings.meta?.senderAddress = senderAddress.isEmpty ? nil : senderAddress

        // Update SMTP settings
        settings.smtp = SMTPSettings(
            enabled: useSMTPMailServer,
            host: smtpHost.isEmpty ? nil : smtpHost,
            port: Int(smtpPort),
            username: smtpUsername.isEmpty ? nil : smtpUsername,
            password: smtpPassword.isEmpty ? nil : smtpPassword,
            authMethod: smtpAuthMethod,
            tls: smtpTLS,
            localName: smtpLocalName.isEmpty ? nil : smtpLocalName
        )

        do {
            try await settings.update(pocketbase: pocketbase)
            successMessage = "Settings saved successfully"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
