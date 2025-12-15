//
//  FilesSettingsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct FilesSettingsView: View {
    @State private var useS3Storage = false

    @State private var endpoint = ""
    @State private var bucket = ""
    @State private var region = ""
    @State private var accessKey = ""
    @State private var secret = ""
    @State private var forcePathStyleAddressing = false

    @State private var isSaving = false
    @State private var isTesting = false
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
                    Text("By default PocketBase uses the local file system to store uploaded files.")
                        .foregroundStyle(.secondary)
                    Text("If you have limited disk space, you could optionally connect to an S3 compatible storage.")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Use S3 storage", isOn: $useS3Storage)
                }

                if useS3Storage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("If you have existing uploaded files, you'll have to migrate them manually from the local file system to the S3 storage.")
                                .font(.callout)
                        }
                    }

                    Section("S3 Configuration") {
                        TextField("Endpoint", text: $endpoint)
                        #if os(iOS)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        #endif

                        TextField("Bucket", text: $bucket)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif

                        TextField("Region", text: $region)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif

                        TextField("Access key", text: $accessKey)
                        #if os(iOS)
                            .autocapitalization(.none)
                        #endif

                        SecureField("Secret", text: $secret)
                    }

                    Section {
                        Toggle("Force path-style addressing", isOn: $forcePathStyleAddressing)
                    } footer: {
                        Text("Enable this for S3-compatible services that require path-style URLs (e.g., MinIO).")
                    }

                    Section {
                        Button {
                            Task {
                                await testS3Connection()
                            }
                        } label: {
                            if isTesting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Test S3 Connection", systemImage: "checkmark.icloud")
                            }
                        }
                        .disabled(isTesting)
                    } footer: {
                        Text("Verify your S3 configuration is working correctly.")
                    }
                }
            }
            .safeAreaPadding()
        }
        .navigationTitle("Files storage")
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Reset") {
                    loadSettings()
                }
                .disabled(isSaving)

                Button("Save") {
                    Task {
                        await saveSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .task {
            loadSettings()
        }
    }

    private func loadSettings() {
        if let s3 = settings.s3 {
            useS3Storage = s3.enabled ?? false
            endpoint = s3.endpoint ?? ""
            bucket = s3.bucket ?? ""
            region = s3.region ?? ""
            accessKey = s3.accessKey ?? ""
            secret = s3.secret ?? ""
            forcePathStyleAddressing = s3.forcePathStyle ?? false
        } else {
            useS3Storage = false
            endpoint = ""
            bucket = ""
            region = ""
            accessKey = ""
            secret = ""
            forcePathStyleAddressing = false
        }
    }

    private func saveSettings() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        settings.s3 = S3Settings(
            enabled: useS3Storage,
            bucket: bucket.isEmpty ? nil : bucket,
            region: region.isEmpty ? nil : region,
            endpoint: endpoint.isEmpty ? nil : endpoint,
            accessKey: accessKey.isEmpty ? nil : accessKey,
            secret: secret.isEmpty ? nil : secret,
            forcePathStyle: forcePathStyleAddressing
        )

        do {
            try await settings.update(pocketbase: pocketbase)
            successMessage = "Settings saved successfully"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func testS3Connection() async {
        isTesting = true
        errorMessage = nil
        successMessage = nil
        defer { isTesting = false }

        do {
            try await pocketbase.admin.settings.testS3()
            successMessage = "S3 connection successful"
        } catch {
            errorMessage = "S3 test failed: \(error.localizedDescription)"
        }
    }
}
