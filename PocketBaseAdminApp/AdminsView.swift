//
//  AdminsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct AdminsView: View {
    @Environment(\.pocketbase) private var pocketbase
    @State private var admins: [RecordModel] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading admins...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if admins.isEmpty {
                ContentUnavailableView {
                    Label("No Admins", systemImage: "person.3")
                } description: {
                    Text("No admin users found.")
                } actions: {
                    Button("Refresh") {
                        Task { await loadAdmins() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List(admins, id: \.id) { admin in
                    VStack(alignment: .leading) {
                        Text(displayText(for: admin))
                            .font(.headline)
                        Text("ID: \(admin.id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .refreshable {
                    await loadAdmins()
                }
            }
        }
        .navigationTitle("Admins")
        .task {
            await loadAdmins()
        }
    }
    
    private func displayText(for admin: RecordModel) -> String {
        // Try to extract email first, then username, then fallback to Unknown
        if let email = admin.email {
            return jsonValueToString(email)
        } else if let username = admin.username {
            return jsonValueToString(username)
        } else {
            return "Unknown"
        }
    }
    
    private func jsonValueToString(_ value: JSONValue) -> String {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return int.description
        case .double(let double):
            return double.description
        case .decimal(let decimal):
            return decimal.description
        case .bool(let bool):
            return bool.description
        case .date(let date):
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
        case .url(let url):
            return url.absoluteString
        case .null:
            return "(Empty)"
        case .array(_), .dictionary(_):
            return "(Complex Value)"
        }
    }
    
    private func loadAdmins() async {
        isLoading = true
        do {
            let result = try await pocketbase.admin.records("_superusers").list(page: 1)
            admins = result.items
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
