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
            let entry = StatsEntry(
                date: Date(),
                collectionsCount: 0,
                recordsCount: 0,
                errorsCount: 0,
                isOnline: true
            )

            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct StatsWidgetView: View {
    var entry: StatsEntry

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
        case .accessoryRectangular:
            rectangularView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack {
                statusIndicator
                Spacer()
            }

            Spacer()

            VStack(spacing: 4) {
                Text("\(entry.collectionsCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .widgetAccentable()
                Text("collections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Text("\(formatCount(entry.recordsCount)) records")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
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

    private var largeView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title2)
                Text("PocketBase Stats")
                    .font(.title2.bold())
                Spacer()
                statusIndicator
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                LargeStatBox(value: entry.collectionsCount, label: "Collections", icon: "rectangle.stack", color: .blue)
                LargeStatBox(value: entry.recordsCount, label: "Records", icon: "doc.text", color: .purple)
                LargeStatBox(value: entry.errorsCount, label: "Errors (24h)", icon: "exclamationmark.circle", color: entry.errorsCount > 0 ? .red : .green)
                LargeStatBox(value: entry.isOnline ? 1 : 0, label: "Status", icon: "wifi", color: entry.isOnline ? .green : .red, displayValue: entry.isOnline ? "Online" : "Offline")
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

    private var rectangularView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("\(entry.collectionsCount)")
                    .font(.headline)
                Text("collections")
                    .font(.caption2)
            }

            Divider()

            VStack(alignment: .leading) {
                Text(formatCount(entry.recordsCount))
                    .font(.headline)
                Text("records")
                    .font(.caption2)
            }
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.isOnline ? .green : .red)
                .frame(width: 8, height: 8)
                .widgetAccentable()
            Text(entry.isOnline ? "Online" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
                .widgetAccentable()
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
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
                .widgetAccentable()

            Text("\(value)")
                .font(.title2.bold())
                .widgetAccentable()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LargeStatBox: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    var displayValue: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .widgetAccentable()

            Text(displayValue ?? formatCount(value))
                .font(.title.bold())
                .widgetAccentable()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
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
#if os(watchOS)
        .supportedFamilies([
            .accessoryRectangular
        ])
#elseif os(iOS)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular
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

#Preview(as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsEntry.snapshot
}
