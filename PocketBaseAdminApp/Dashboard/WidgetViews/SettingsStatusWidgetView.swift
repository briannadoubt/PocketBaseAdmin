//
//  SettingsStatusWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Settings status widget showing server configuration
struct SettingsStatusWidgetView: View {
    let data: SettingsStatusData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let appName = data.appName, !appName.isEmpty {
                        Text(appName)
                            .font(.title2.bold())
                            .lineLimit(1)
                    } else {
                        Text("Configuration")
                            .font(.title2.bold())
                    }
                }
                Spacer()
                Image(systemName: "gearshape.2")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Status items
            VStack(spacing: 8) {
                SettingsStatusRow(
                    icon: "envelope",
                    label: "SMTP",
                    isEnabled: data.smtpEnabled
                )

                SettingsStatusRow(
                    icon: "cloud",
                    label: "S3 Storage",
                    isEnabled: data.s3Enabled
                )

                SettingsStatusRow(
                    icon: "clock.arrow.circlepath",
                    label: "Auto Backups",
                    isEnabled: data.backupsEnabled,
                    detail: data.backupCron
                )
            }

            if let url = data.appUrl, !url.isEmpty {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(url)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsStatusRow: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)

            Spacer()

            if let detail = detail, isEnabled {
                Text(detail)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(isEnabled ? .green : .secondary)
        }
    }
}

#Preview {
    SettingsStatusWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
