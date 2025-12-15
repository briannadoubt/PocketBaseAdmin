//
//  ErrorCountWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ErrorCountEntry: TimelineEntry {
    let date: Date
    let errorCount: Int
    let period: String

    static var placeholder: ErrorCountEntry {
        ErrorCountEntry(date: Date(), errorCount: 0, period: "24h")
    }

    static var snapshot: ErrorCountEntry {
        ErrorCountEntry(date: Date(), errorCount: 3, period: "24h")
    }

    var color: Color {
        switch errorCount {
        case 0: return .green
        case 1...5: return .yellow
        default: return .red
        }
    }
}

// MARK: - Timeline Provider

struct ErrorCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> ErrorCountEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ErrorCountEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ErrorCountEntry>) -> Void) {
        Task {
            // TODO: Use PocketBaseIntents.GetErrorCountIntent when linked
            let entry = ErrorCountEntry(
                date: Date(),
                errorCount: 0,
                period: "24h"
            )

            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct ErrorCountWidgetView: View {
    var entry: ErrorCountEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryCircular:
            circularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 4) {
            Text("\(entry.errorCount)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(entry.color)

            Text(entry.errorCount == 1 ? "error" : "errors")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("last \(entry.period)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.errorCount)")
                    .font(.title2.bold())
                    .foregroundStyle(entry.color)
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Widget Definition

struct ErrorCountWidget: Widget {
    let kind: String = "ErrorCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ErrorCountProvider()) { entry in
            ErrorCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Error Count")
        .description("Track errors in the last 24 hours")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular
        ])
    }
}

#Preview(as: .systemSmall) {
    ErrorCountWidget()
} timeline: {
    ErrorCountEntry.snapshot
    ErrorCountEntry(date: Date(), errorCount: 0, period: "24h")
    ErrorCountEntry(date: Date(), errorCount: 12, period: "24h")
}
