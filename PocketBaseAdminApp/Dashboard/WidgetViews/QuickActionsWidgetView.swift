//
//  QuickActionsWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import PocketBase

/// Quick actions widget with common action buttons
struct QuickActionsWidgetView: View {
    let pocketbase: PocketBase
    var onRefresh: (() -> Void)?

    @State private var isCreatingBackup = false
    @State private var backupError: String?
    @State private var showBackupSuccess = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Quick Actions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            // Action buttons
            VStack(spacing: 8) {
                Button {
                    onRefresh?()
                } label: {
                    Label("Refresh Dashboard", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    createBackup()
                } label: {
                    if isCreatingBackup {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Create Backup", systemImage: "externaldrive.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isCreatingBackup)
            }

            // Status messages
            if let error = backupError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if showBackupSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Backup created")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.default, value: showBackupSuccess)
        .animation(.default, value: backupError)
    }

    private func createBackup() {
        Task {
            isCreatingBackup = true
            backupError = nil
            showBackupSuccess = false

            do {
                try await pocketbase.admin.backups.create(name: "")
                showBackupSuccess = true
                onRefresh?()

                // Hide success message after 3 seconds
                try? await Task.sleep(for: .seconds(3))
                showBackupSuccess = false
            } catch {
                backupError = error.localizedDescription
            }

            isCreatingBackup = false
        }
    }
}

#Preview {
    QuickActionsWidgetView(pocketbase: .localhost)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
