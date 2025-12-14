//
//  HealthDashboardView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import PocketBase
import PocketBaseAdmin

struct HealthDashboardView: View {
    @State private var healthStatus: HealthStatus?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastChecked: Date?

    @Environment(\.pocketbase) private var pocketbase

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status card
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .frame(height: 60)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.red)
                            Text("Connection Error")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if let health = healthStatus {
                        VStack(spacing: 12) {
                            Image(systemName: health.code == 200 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(health.code == 200 ? .green : .red)

                            Text(health.message)
                                .font(.headline)

                            if let version = health.data.version {
                                Text("PocketBase v\(version)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Not checked yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let lastChecked {
                        Text("Last checked: \(lastChecked, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task {
                            await checkHealth()
                        }
                    } label: {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.05))
                )

                // Details section
                if let health = healthStatus {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("System Status")
                            .font(.headline)

                        VStack(spacing: 0) {
                            StatusRow(
                                label: "HTTP Status",
                                value: "\(health.code)",
                                isHealthy: health.code == 200
                            )
                            Divider()
                            StatusRow(
                                label: "Can Backup",
                                value: health.data.canBackup ? "Yes" : "No",
                                isHealthy: health.data.canBackup
                            )
                            if let version = health.data.version {
                                Divider()
                                StatusRow(
                                    label: "Version",
                                    value: version,
                                    isHealthy: true
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Server info section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Server Configuration")
                        .font(.headline)

                    VStack(spacing: 0) {
                        StatusRow(
                            label: "URL",
                            value: pocketbase.url.absoluteString,
                            isHealthy: true
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Health")
        .task {
            await checkHealth()
        }
    }

    private func checkHealth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            healthStatus = try await pocketbase.admin.health.check()
            lastChecked = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let isHealthy: Bool

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Text(value)
                    .fontWeight(.medium)
                Image(systemName: isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isHealthy ? .green : .red)
            }
        }
        .padding()
    }
}
