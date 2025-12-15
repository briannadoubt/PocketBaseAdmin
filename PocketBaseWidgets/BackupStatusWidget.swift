//
//  BackupStatusWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct BackupStatusEntry: TimelineEntry {
    let date: Date
    let lastBackupDate: Date?
    let lastBackupName: String?

    static var placeholder: BackupStatusEntry {
        BackupStatusEntry(date: Date(), lastBackupDate: Date(), lastBackupName: "backup_2024.zip")
    }

    static var snapshot: BackupStatusEntry {
        BackupStatusEntry(
            date: Date(),
            lastBackupDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            lastBackupName: "backup_2024.zip"
        )
    }

    var isRecent: Bool {
        guard let lastBackup = lastBackupDate else { return false }
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return lastBackup > dayAgo
    }

    var statusColor: Color {
        guard let lastBackup = lastBackupDate else { return .red }
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        if lastBackup > dayAgo {
            return .green
        } else if lastBackup > weekAgo {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Timeline Provider

struct BackupStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> BackupStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BackupStatusEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BackupStatusEntry>) -> Void) {
        Task {
            // TODO: Use PocketBaseIntents.ListBackupsIntent when linked
            let entry = BackupStatusEntry(
                date: Date(),
                lastBackupDate: nil,
                lastBackupName: nil
            )

            // Refresh every hour
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct BackupStatusWidgetView: View {
    var entry: BackupStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.statusColor)

            if let lastBackup = entry.lastBackupDate {
                Text("Last Backup")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(lastBackup, style: .relative)
                    .font(.headline)
            } else {
                Text("No Backups")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text("Create one now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(entry.statusColor)

            VStack(alignment: .leading) {
                Text("Backup")
                    .font(.caption2)

                if let lastBackup = entry.lastBackupDate {
                    Text(lastBackup, style: .relative)
                        .font(.caption.bold())
                } else {
                    Text("None")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct BackupStatusWidget: Widget {
    let kind: String = "BackupStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BackupStatusProvider()) { entry in
            BackupStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Backup Status")
        .description("See when you last backed up your database")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular
        ])
    }
}

#Preview(as: .systemSmall) {
    BackupStatusWidget()
} timeline: {
    BackupStatusEntry.snapshot
}
