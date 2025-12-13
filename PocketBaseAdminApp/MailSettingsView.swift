//
//  MailSettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI

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
    var title: String
    
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
