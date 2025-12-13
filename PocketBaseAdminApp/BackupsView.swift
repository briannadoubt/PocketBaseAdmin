//
//  BackupsView.swift
//  PocketBaseAdminApp
//
//  Created by Brianna Zamora on 6/28/25.
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct BackupsView: View {
    @State private var backups: [BackupModel] = []
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    @State private var showNewBackupSheet = false
    @State private var newBackupName = ""

    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: BackupModel?

    @State private var showOptionsSheet = false

    @Environment(\.pocketbase) private var pocketbase
    @Environment(Admin.Settings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                }

                // Backups list
                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if backups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "archivebox")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No backups yet")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                    } else {
                        ForEach(backups) { backup in
                            BackupRow(
                                backup: backup,
                                onDelete: {
                                    backupToDelete = backup
                                    showDeleteConfirmation = true
                                }
                            )

                            if backup.id != backups.last?.id {
                                Divider()
                            }
                        }
                    }

                    Divider()

                    Button {
                        showNewBackupSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Create new backup")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreating)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.05))
                        )
                )
                .padding(.horizontal)

                // Options section
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        showOptionsSheet = true
                    } label: {
                        HStack {
                            Text("Backup Options")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Backups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await loadBackups()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadBackups()
        }
        .sheet(isPresented: $showNewBackupSheet) {
            CreateBackupSheet(
                backupName: $newBackupName,
                isCreating: isCreating,
                onCreate: {
                    Task {
                        await createBackup()
                    }
                },
                onCancel: {
                    showNewBackupSheet = false
                    newBackupName = ""
                }
            )
        }
        .sheet(isPresented: $showOptionsSheet) {
            BackupOptionsSheet(settings: settings, pocketbase: pocketbase)
        }
        .alert("Delete Backup?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                backupToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let backup = backupToDelete {
                    Task {
                        await deleteBackup(backup)
                    }
                }
            }
        } message: {
            if let backup = backupToDelete {
                Text("Are you sure you want to delete \"\(backup.key)\"? This action cannot be undone.")
            }
        }
    }

    private func loadBackups() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            backups = try await pocketbase.admin.backups.list()
                .sorted { $0.modified > $1.modified }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createBackup() async {
        isCreating = true
        errorMessage = nil
        defer {
            isCreating = false
            showNewBackupSheet = false
            newBackupName = ""
        }

        do {
            let name = newBackupName.isEmpty ? nil : newBackupName
            try await pocketbase.admin.backups.create(name: name)
            await loadBackups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteBackup(_ backup: BackupModel) async {
        errorMessage = nil

        do {
            try await pocketbase.admin.backups.delete(name: backup.key)
            backups.removeAll { $0.id == backup.id }
            backupToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BackupRow: View {
    let backup: BackupModel
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.key)
                    .fontWeight(.medium)
                HStack(spacing: 12) {
                    Text(backup.formattedSize)
                        .foregroundStyle(.secondary)
                    Text(backup.modified, style: .relative)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }
}

struct CreateBackupSheet: View {
    @Binding var backupName: String
    let isCreating: Bool
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("During the backup, other concurrent write requests may fail since the database will be temporarily locked.\n\nIf you are using S3 storage for file uploads, those files will not be included in the backup.")
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                }

                Section("Backup Name (optional)") {
                    TextField("Leave empty for auto-generated name", text: $backupName)
                    #if os(iOS)
                        .autocapitalization(.none)
                    #endif
                }
            }
            .navigationTitle("New Backup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                    }
                    .disabled(isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
        .presentationDetents([.medium])
    }
}

struct BackupOptionsSheet: View {
    let settings: Admin.Settings
    let pocketbase: PocketBase

    @State private var cronExpression = ""
    @State private var cronTimezone = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                    TextField("Cron expression", text: $cronExpression)
                    #if os(iOS)
                        .autocapitalization(.none)
                    #endif
                } header: {
                    Text("Auto Backup Schedule")
                } footer: {
                    Text("Leave empty to disable auto backups. Example: 0 0 * * * (daily at midnight)")
                }

                Section("Timezone") {
                    TextField("Timezone (e.g., UTC, America/New_York)", text: $cronTimezone)
                    #if os(iOS)
                        .autocapitalization(.none)
                    #endif
                }
            }
            .navigationTitle("Backup Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveOptions()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            cronExpression = settings.backups?.cron ?? ""
            cronTimezone = settings.backups?.cronTimezone ?? ""
        }
    }

    private func saveOptions() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }

        settings.backups = BackupsSettings(
            cron: cronExpression.isEmpty ? nil : cronExpression,
            cronTimezone: cronTimezone.isEmpty ? nil : cronTimezone
        )

        do {
            try await settings.update(pocketbase: pocketbase)
            successMessage = "Options saved"
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
