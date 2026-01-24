//
//  WatchWidgets.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI
import PocketBaseIntents

// MARK: - Timeline Entry

struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let isOnline: Bool
    let latency: TimeInterval?
    let errorCount: Int
    let lastBackup: Date?
    let collectionsCount: Int
}

// MARK: - Timeline Provider

struct ServerStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isOnline: true,
            latency: 0.042,
            errorCount: 0,
            lastBackup: Date().addingTimeInterval(-3600),
            collectionsCount: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        let entry = ServerStatusEntry(
            date: Date(),
            isOnline: true,
            latency: 0.042,
            errorCount: 2,
            lastBackup: Date().addingTimeInterval(-7200),
            collectionsCount: 5
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        Task { @MainActor in
            // Fetch all data in parallel
            async let status = IntentHelpers.fetchServerStatus()
            async let collections = IntentHelpers.fetchCollections()
            async let errorCount = IntentHelpers.fetchErrorCount()
            async let backupStatus = IntentHelpers.fetchBackupStatus()

            let entry = ServerStatusEntry(
                date: Date(),
                isOnline: await status.isOnline,
                latency: await status.latency,
                errorCount: await errorCount,
                lastBackup: await backupStatus.lastBackupDate,
                collectionsCount: await collections.count
            )

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Server Status Complication

struct ServerStatusComplication: Widget {
    let kind: String = "ServerStatusComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            ServerStatusComplicationView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Monitor your PocketBase server status")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct ServerStatusComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: ServerStatusEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(entry.isOnline ? .green : .red)
                if let latency = entry.latency {
                    Text("\(Int(latency * 1000))ms")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(entry.isOnline ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isOnline ? "Online" : "Offline")
                    .font(.headline)
                if let latency = entry.latency {
                    Text("\(Int(latency * 1000))ms latency")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(entry.isOnline ? "PB Online" : "PB Offline")
        }
    }

    private var cornerView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(entry.isOnline ? .green : .red)
        }
        .widgetLabel {
            Text(entry.isOnline ? "Online" : "Offline")
        }
    }
}

// MARK: - Error Count Complication

struct ErrorCountComplication: Widget {
    let kind: String = "ErrorCountComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            ErrorCountComplicationView(entry: entry)
        }
        .configurationDisplayName("Error Count")
        .description("See errors from the last 24 hours")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct ErrorCountComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: ServerStatusEntry

    private var errorColor: Color {
        if entry.errorCount == 0 {
            return .green
        } else if entry.errorCount < 5 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Text("\(entry.errorCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(errorColor)
                Text("Errors")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(errorColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.errorCount == 0 ? "No Errors" : "\(entry.errorCount) Errors")
                    .font(.headline)
                Text("Last 24 hours")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(entry.errorCount == 0 ? "No errors" : "\(entry.errorCount) errors")
        }
    }
}

// MARK: - Backup Status Complication

struct BackupStatusComplication: Widget {
    let kind: String = "BackupStatusComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            BackupStatusComplicationView(entry: entry)
        }
        .configurationDisplayName("Backup Status")
        .description("See when your last backup was created")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct BackupStatusComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: ServerStatusEntry

    private var backupAge: String {
        guard let lastBackup = entry.lastBackup else {
            return "Never"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastBackup, relativeTo: Date())
    }

    private var backupColor: Color {
        guard let lastBackup = entry.lastBackup else {
            return .red
        }
        let hoursSinceBackup = Date().timeIntervalSince(lastBackup) / 3600
        if hoursSinceBackup < 24 {
            return .green
        } else if hoursSinceBackup < 72 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(backupColor)
                Text(backupAge)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(backupColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Backup")
                    .font(.headline)
                Text(backupAge)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "archivebox.fill")
            Text("Backup: \(backupAge)")
        }
    }
}

// MARK: - Stats Complication

struct StatsComplication: Widget {
    let kind: String = "StatsComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            StatsComplicationView(entry: entry)
        }
        .configurationDisplayName("Quick Stats")
        .description("Collections and errors at a glance")
        .supportedFamilies([
            .accessoryRectangular
        ])
    }
}

struct StatsComplicationView: View {
    let entry: ServerStatusEntry

    var body: some View {
        HStack(spacing: 12) {
            // Status
            VStack(spacing: 2) {
                Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(entry.isOnline ? .green : .red)
                Text(entry.isOnline ? "On" : "Off")
                    .font(.system(size: 9))
            }

            Divider()

            // Collections
            VStack(spacing: 2) {
                Text("\(entry.collectionsCount)")
                    .font(.headline)
                Text("Cols")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Errors
            VStack(spacing: 2) {
                Text("\(entry.errorCount)")
                    .font(.headline)
                    .foregroundStyle(entry.errorCount > 0 ? .red : .green)
                Text("Errs")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Bundle
// Note: This WidgetBundle should be the entry point for a separate
// "PocketBase Watch Widgets" Widget Extension target in Xcode.
// Remove the @main from PocketBaseApp.swift if using this in the main app,
// or create a new Widget Extension target and add this file to it.

struct PocketBaseWatchWidgets: WidgetBundle {
    var body: some Widget {
        ServerStatusComplication()
        ErrorCountComplication()
        BackupStatusComplication()
        StatsComplication()
    }
}

// MARK: - Previews

#Preview("Circular - Online", as: .accessoryCircular) {
    ServerStatusComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, errorCount: 0, lastBackup: Date(), collectionsCount: 5)
}

#Preview("Circular - Offline", as: .accessoryCircular) {
    ServerStatusComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: false, latency: nil, errorCount: 3, lastBackup: nil, collectionsCount: 5)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ServerStatusComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, errorCount: 0, lastBackup: Date(), collectionsCount: 5)
}

#Preview("Inline", as: .accessoryInline) {
    ServerStatusComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, errorCount: 0, lastBackup: Date(), collectionsCount: 5)
}

#Preview("Error Count", as: .accessoryCircular) {
    ErrorCountComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, errorCount: 7, lastBackup: Date(), collectionsCount: 5)
}

#Preview("Stats", as: .accessoryRectangular) {
    StatsComplication()
} timeline: {
    ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, errorCount: 2, lastBackup: Date(), collectionsCount: 8)
}
