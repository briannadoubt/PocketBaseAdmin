//
//  ServerStatusWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI
import AppIntents
import PocketBaseIntents

// MARK: - Timeline Entry

struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let isOnline: Bool
    let latency: TimeInterval?
    let lastChecked: Date

    static var placeholder: ServerStatusEntry {
        ServerStatusEntry(date: Date(), isOnline: true, latency: 0.05, lastChecked: Date())
    }

    static var snapshot: ServerStatusEntry {
        ServerStatusEntry(date: Date(), isOnline: true, latency: 0.042, lastChecked: Date())
    }
}

// MARK: - Timeline Provider

struct ServerStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ServerStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        Task { @MainActor in
            let status = await IntentHelpers.fetchServerStatus()

            let entry = ServerStatusEntry(
                date: Date(),
                isOnline: status.isOnline,
                latency: status.latency,
                lastChecked: status.checkedAt
            )

            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct ServerStatusWidgetView: View {
    var entry: ServerStatusEntry

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
            statusIndicator
                .font(.system(size: 44))

            Text(entry.isOnline ? "Online" : "Offline")
                .font(.headline)
                .widgetAccentable()

            if let latency = entry.latency {
                Text("\(Int(latency * 1000))ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.lastChecked, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            statusIndicator
                .font(.system(size: 56))

            VStack(alignment: .leading, spacing: 4) {
                Text("PocketBase")
                    .font(.headline)

                Text(entry.isOnline ? "Server Online" : "Server Offline")
                    .font(.subheadline)
                    .foregroundStyle(entry.isOnline ? .green : .red)
                    .widgetAccentable()

                if let latency = entry.latency {
                    Text("Response: \(Int(latency * 1000))ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Updated \(entry.lastChecked, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title2)
                Text("PocketBase Server")
                    .font(.title2.bold())
                Spacer()
            }

            HStack(spacing: 24) {
                VStack {
                    statusIndicator
                        .font(.system(size: 72))
                    Text(entry.isOnline ? "Online" : "Offline")
                        .font(.title3.bold())
                        .foregroundStyle(entry.isOnline ? .green : .red)
                        .widgetAccentable()
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let latency = entry.latency {
                        LargeStatRow(icon: "bolt", label: "Latency", value: "\(Int(latency * 1000))ms")
                    }
                    LargeStatRow(icon: "clock", label: "Last Check", value: entry.lastChecked.formatted(date: .omitted, time: .shortened))
                    LargeStatRow(icon: "arrow.clockwise", label: "Next Update", value: "15 min")
                }

                Spacer()
            }

            Spacer(minLength: 0)

            HStack {
                Text("Tap to open admin panel")
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
            statusIndicator
                .font(.title)
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            statusIndicator
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("PocketBase")
                    .font(.headline)
                Text(entry.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(entry.isOnline ? .green : .red)
                    .widgetAccentable()
            }
        }
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(entry.isOnline ? "PB: Online" : "PB: Offline")
        }
    }

    private var statusIndicator: some View {
        Image(systemName: entry.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(entry.isOnline ? .green : .red)
            .widgetAccentable()
    }
}

struct StatRow: View {
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
        }
        .font(.subheadline)
    }
}

struct LargeStatRow: View {
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
            }
        }
    }
}

// MARK: - Widget Definition

struct ServerStatusWidget: Widget {
    let kind: String = "ServerStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            ServerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Monitor your PocketBase server status")
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
    ServerStatusWidget()
} timeline: {
    ServerStatusEntry.snapshot
}
