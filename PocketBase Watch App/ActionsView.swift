//
//  ActionsView.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import WatchKit

struct ActionsView: View {
    @State private var isCreatingBackup = false
    @State private var showBackupConfirmation = false
    @State private var lastBackupDate: Date?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Create Backup
                ActionButton(
                    title: "Create Backup",
                    icon: "archivebox.fill",
                    color: .blue,
                    isLoading: isCreatingBackup
                ) {
                    Task { await createBackup() }
                }

                // Last backup info
                if let lastBackup = lastBackupDate {
                    Text("Last backup: \(lastBackup, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                // Refresh widgets
                ActionButton(
                    title: "Refresh Widgets",
                    icon: "arrow.clockwise",
                    color: .green,
                    isLoading: false
                ) {
                    refreshWidgets()
                }

                // View in app
                ActionButton(
                    title: "Open App",
                    icon: "iphone",
                    color: .orange,
                    isLoading: false
                ) {
                    // This would open the companion app
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Actions")
        .alert("Backup Created", isPresented: $showBackupConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your database has been backed up successfully.")
        }
    }

    private func createBackup() async {
        isCreatingBackup = true
        errorMessage = nil

        // Haptic feedback
        WKInterfaceDevice.current().play(.start)

        defer { isCreatingBackup = false }

        do {
            // TODO: Use CreateBackupIntent
            // For now, simulate
            try await Task.sleep(for: .seconds(2))

            lastBackupDate = Date()
            showBackupConfirmation = true

            // Success haptic
            WKInterfaceDevice.current().play(.success)
        } catch {
            errorMessage = error.localizedDescription
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func refreshWidgets() {
        WKInterfaceDevice.current().play(.click)
        // TODO: Trigger widget refresh via WidgetCenter
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.callout)

                Spacer()

                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    NavigationStack {
        ActionsView()
    }
}
