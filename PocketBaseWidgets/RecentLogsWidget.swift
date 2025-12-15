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
            WidgetLogEntry(id: "3", level: .error, message: "Connection timeout", timestamp: Date().addingTimeInterval(-600))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if entry.logs.isEmpty {
                emptyView
            } else {
                logsListView
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var headerView: some View {
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
            ForEach(entry.logs.prefix(5)) { log in
                LogRowView(log: log)
            }

            if entry.logs.count > 5 {
                Text("+ \(entry.logs.count - 5) more")
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
        .supportedFamilies([.systemLarge])
    }
}

#Preview(as: .systemLarge) {
    RecentLogsWidget()
} timeline: {
    RecentLogsEntry.snapshot
}
