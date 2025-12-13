//
//  ApplicationSettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct ApplicationSettingsView: View {
    @State private var hideCollectionCreateAndEditControls = false
    @State private var appName = ""
    @State private var appURL = ""
    
    @Environment(\.pocketbase) private var pocketbase
    @EnvironmentBound(Admin.Settings.self) private var settings
    
    var body: some View {
        ScrollView {
            Form {
                Section {
                    TextField("Application name", text: $appName)
                    TextField("Application URL", text: $appURL)
                }
                Section {
                    Toggle("Hide collection create and edit controls", isOn: $hideCollectionCreateAndEditControls)
                }
                Section {
                    Button("Save changes") {
                        Task {
                            do {
                                try await settings.update(pocketbase: pocketbase)
                            } catch {
                                print(
                                    "Failed to update settings: \(String(describing: error))"
                                )
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .safeAreaPadding()
            .listStyle(.inset)
        }
        .navigationTitle("Application")
        .task {
            guard let meta = settings.meta else {
                do {
                    try await settings.load(pocketbase: pocketbase)
                } catch {
                    print(
                        "Failed to load settings: \(error)"
                    )
                }
                guard let meta = settings.meta else {
                    print("Failed to load settings, like actually though.")
                    return
                }
                appURL = meta.appUrl ?? ""
                appName = meta.appName ?? ""
                return
            }
            appURL = meta.appUrl ?? ""
            appName = meta.appName ?? ""
        }
    }
}

