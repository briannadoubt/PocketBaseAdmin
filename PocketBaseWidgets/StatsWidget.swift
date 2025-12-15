//
//  StatsWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let collectionsCount: Int
    let recordsCount: Int
    let errorsCount: Int
    let isOnline: Bool

    static var placeholder: StatsEntry {
        StatsEntry(
            date: Date(),
            collectionsCount: 5,
            recordsCount: 1234,
            errorsCount: 0,
            isOnline: true
        )
    }

    static var snapshot: StatsEntry {
        StatsEntry(
            date: Date(),
            collectionsCount: 8,
            recordsCount: 5432,
            errorsCount: 2,
            isOnline: true
        )
    }
}

// MARK: - Timeline Provider

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        Task {
            // TODO: Use PocketBaseIntents when linked
            let entry = StatsEntry(
                date: Date(),
                collectionsCount: 0,
                recordsCount: 0,
                errorsCount: 0,
                isOnline: true
            )

            // Refresh every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct StatsWidgetView: View {
    var entry: StatsEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                Text("PocketBase Stats")
                    .font(.headline)
                Spacer()
                statusIndicator
            }

            HStack(spacing: 16) {
                StatBox(
                    value: entry.collectionsCount,
                    label: "Collections",
                    icon: "rectangle.stack",
                    color: .blue
                )

                StatBox(
                    value: entry.recordsCount,
                    label: "Records",
                    icon: "doc.text",
                    color: .purple
                )

                StatBox(
                    value: entry.errorsCount,
                    label: "Errors (24h)",
                    icon: "exclamationmark.circle",
                    color: entry.errorsCount > 0 ? .red : .green
                )
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.isOnline ? .green : .red)
                .frame(width: 8, height: 8)
            Text(entry.isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatBox: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value)")
                .font(.title2.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Widget Definition

struct StatsWidget: Widget {
    let kind: String = "StatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            StatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Server Stats")
        .description("View your PocketBase statistics at a glance")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsEntry.snapshot
}
