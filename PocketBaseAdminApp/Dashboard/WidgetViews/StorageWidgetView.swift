//
//  StorageWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI

/// Storage widget showing backup count and size with a progress indicator
struct StorageWidgetView: View {
    let data: StorageData

    var body: some View {
        VStack(spacing: 12) {
            // Icon and size
            HStack(spacing: 16) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(data.formattedSize)
                        .font(.title2.bold())

                    Text("\(data.backupCount) backups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Last backup info
            if let lastBackup = data.lastBackupDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Last backup: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(lastBackup, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("No backups yet")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Spacer()
                }
            }

            // Visual indicator
            Gauge(value: Double(data.backupCount), in: 0...10) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(.teal)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StorageWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
