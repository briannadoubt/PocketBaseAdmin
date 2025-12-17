//
//  RecentLogsWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

// MARK: - Log Entry Model

struct WidgetLogEntry: Identifiable {
    let id: String
    let level: WidgetLogLevel
    let message: String
    let timestamp: Date
}

enum WidgetLogLevel: Int {
    case debug = -4
    case info = 0
    case warning = 4
    case error = 8

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

// MARK: - Timeline Entry

struct RecentLogsEntry: TimelineEntry {
    let date: Date
    let logs: [WidgetLogEntry]

    static var placeholder: RecentLogsEntry {
        RecentLogsEntry(date: Date(), logs: [
            WidgetLogEntry(id: "1", level: .info, message: "Request completed", timestamp: Date()),
            WidgetLogEntry(id: "2", level: .warning, message: "Slow query detected", timestamp: Date().addingTimeInterval(-300)),
            WidgetLogEntry(id: "3", level: .error, message: "Connection timeout", timestamp: Date().addingTimeInterval(-600)),
            WidgetLogEntry(id: "4", level: .info, message: "User authenticated", timestamp: Date().addingTimeInterval(-900)),
            WidgetLogEntry(id: "5", level: .debug, message: "Cache cleared", timestamp: Date().addingTimeInterval(-1200)),
            WidgetLogEntry(id: "6", level: .info, message: "Backup completed", timestamp: Date().addingTimeInterval(-1500)),
            WidgetLogEntry(id: "7", level: .warning, message: "Rate limit approaching", timestamp: Date().addingTimeInterval(-1800)),
            WidgetLogEntry(id: "8", level: .info, message: "Collection updated", timestamp: Date().addingTimeInterval(-2100))
        ])
    }

    static var snapshot: RecentLogsEntry {
        placeholder
    }

    var errorCount: Int {
        logs.filter { $0.level == .error }.count
    }
}

// MARK: - Timeline Provider

struct RecentLogsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentLogsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentLogsEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentLogsEntry>) -> Void) {
        Task {
            // TODO: Use PocketBaseIntents.GetRecentLogsIntent when linked
            let entry = RecentLogsEntry(date: Date(), logs: [])

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct RecentLogsWidgetView: View {
    var entry: RecentLogsEntry

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
            largeView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.errorCount > 0 ? .red : .blue)
                .widgetAccentable()

            if entry.errorCount > 0 {
                Text("\(entry.errorCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .widgetAccentable()
                Text(entry.errorCount == 1 ? "error" : "errors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No Errors")
                    .font(.headline)
                    .widgetAccentable()
                Text("All clear")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Recent Logs")
                    .font(.headline)
                Spacer()

                if entry.errorCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("\(entry.errorCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }
            }

            if entry.logs.isEmpty {
                HStack {
                    Spacer()
                    Text("No recent logs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.logs.prefix(3)) { log in
                        LogRowView(log: log)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if entry.logs.isEmpty {
                emptyView
            } else {
                logsListView
            }

            Spacer(minLength: 0)

            HStack {
                Text("Updated \(entry.date, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.errorCount)")
                    .font(.title2.bold())
                    .foregroundStyle(entry.errorCount > 0 ? .red : .green)
                    .widgetAccentable()
                Image(systemName: entry.errorCount > 0 ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.caption2)
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading) {
                Text("\(entry.errorCount)")
                    .font(.title.bold())
                    .foregroundStyle(entry.errorCount > 0 ? .red : .green)
                    .widgetAccentable()
                Text(entry.errorCount == 1 ? "error" : "errors")
                    .font(.caption2)
            }

            Divider()

            if let latestLog = entry.logs.first {
                VStack(alignment: .leading) {
                    Image(systemName: latestLog.level.icon)
                        .foregroundStyle(latestLog.level.color)
                        .widgetAccentable()
                    Text(latestLog.message)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } else {
                Text("No logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: entry.errorCount > 0 ? "exclamationmark.circle" : "checkmark.circle")
                .widgetAccentable()
            Text("\(entry.errorCount) \(entry.errorCount == 1 ? "error" : "errors")")
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(.blue)
                .widgetAccentable()
            Text("Recent Logs")
                .font(.headline)
            Spacer()

            if entry.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .widgetAccentable()
                    Text("\(entry.errorCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .widgetAccentable()
                }
            }
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No recent logs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var logsListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.logs.prefix(8)) { log in
                LogRowView(log: log)
            }

            if entry.logs.count > 8 {
                Text("+ \(entry.logs.count - 8) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct LogRowView: View {
    let log: WidgetLogEntry

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(log.level.color)
                .frame(width: 8, height: 8)
                .widgetAccentable()

            Text(log.message)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(log.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Widget Definition

struct RecentLogsWidget: Widget {
    let kind: String = "RecentLogsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentLogsProvider()) { entry in
            RecentLogsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Logs")
        .description("View the most recent log entries")
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
    RecentLogsWidget()
} timeline: {
    RecentLogsEntry.snapshot
}

#Preview(as: .systemMedium) {
    RecentLogsWidget()
} timeline: {
    RecentLogsEntry.snapshot
}

#Preview(as: .systemLarge) {
    RecentLogsWidget()
} timeline: {
    RecentLogsEntry.snapshot
}
