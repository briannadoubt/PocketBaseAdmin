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
    let backupCount: Int

    static var placeholder: BackupStatusEntry {
        BackupStatusEntry(date: Date(), lastBackupDate: Date(), lastBackupName: "backup_2024.zip", backupCount: 5)
    }

    static var snapshot: BackupStatusEntry {
        BackupStatusEntry(
            date: Date(),
            lastBackupDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            lastBackupName: "backup_2024.zip",
            backupCount: 5
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

    var statusMessage: String {
        guard let lastBackup = lastBackupDate else { return "No backups" }
        let dayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        if lastBackup > dayAgo {
            return "Recent backup"
        } else if lastBackup > weekAgo {
            return "Backup aging"
        } else {
            return "Backup stale"
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
            let entry = BackupStatusEntry(
                date: Date(),
                lastBackupDate: nil,
                lastBackupName: nil,
                backupCount: 0
            )

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
    @Environment(\.widgetRenderingMode) var renderingMode
    @Environment(\.showsWidgetContainerBackground) var showsBackground

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.statusColor)
                .widgetAccentable()

            if let lastBackup = entry.lastBackupDate {
                Text("Last Backup")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(lastBackup, style: .relative)
                    .font(.headline)
                    .widgetAccentable()
            } else {
                Text("No Backups")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .widgetAccentable()

                Text("Create one now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(entry.statusColor)
                    .widgetAccentable()

                Text("\(entry.backupCount)")
                    .font(.title2.bold())
                    .widgetAccentable()
                Text("backups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Backup Status")
                    .font(.headline)

                if let lastBackup = entry.lastBackupDate {
                    HStack {
                        Circle()
                            .fill(entry.statusColor)
                            .frame(width: 8, height: 8)
                            .widgetAccentable()
                        Text(entry.statusMessage)
                            .font(.subheadline)
                            .widgetAccentable()
                    }

                    Text("Last: \(lastBackup, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .widgetAccentable()
                        Text("No backups found")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .widgetAccentable()
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(entry.statusColor)
                    .widgetAccentable()
                Text("Backup Status")
                    .font(.headline)
                Spacer()
                Text(entry.statusMessage)
                    .font(.caption.bold())
                    .foregroundStyle(entry.statusColor)
                    .widgetAccentable()
            }

            HStack(spacing: 16) {
                VStack {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(entry.statusColor)
                        .widgetAccentable()
                }
                .frame(width: 80)

                VStack(alignment: .leading, spacing: 8) {
                    LargeBackupStatRow(icon: "number", label: "Total Backups", value: "\(entry.backupCount)")

                    if let lastBackup = entry.lastBackupDate {
                        LargeBackupStatRow(icon: "clock", label: "Last Backup", value: lastBackup.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let name = entry.lastBackupName {
                        LargeBackupStatRow(icon: "doc.zipper", label: "File", value: name)
                    }
                }
            }

            Divider()

            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Regular backups protect your data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("Tap to manage backups")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(entry.statusColor)
                    .widgetAccentable()
                if entry.lastBackupDate != nil {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .widgetAccentable()
                } else {
                    Image(systemName: "exclamationmark")
                        .font(.caption2)
                        .widgetAccentable()
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(entry.statusColor)
                .widgetAccentable()

            VStack(alignment: .leading) {
                Text("Backup")
                    .font(.caption2)

                if let lastBackup = entry.lastBackupDate {
                    Text(lastBackup, style: .relative)
                        .font(.caption.bold())
                        .widgetAccentable()
                } else {
                    Text("None")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .widgetAccentable()
                }
            }
        }
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .widgetAccentable()
            if let lastBackup = entry.lastBackupDate {
                Text("Backup: \(lastBackup, style: .relative)")
            } else {
                Text("No backups")
            }
        }
    }
}

struct BackupStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .font(.subheadline)
    }
}

struct LargeBackupStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
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
#if os(watchOS)
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
#elseif os(iOS)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
#else
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
#endif
    }
}

#Preview(as: .systemSmall) {
    BackupStatusWidget()
} timeline: {
    BackupStatusEntry.snapshot
}
