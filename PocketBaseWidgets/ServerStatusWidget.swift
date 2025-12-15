//
//  ServerStatusWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI
import AppIntents

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
        Task {
            do {
                let startTime = Date()
                // TODO: Use PocketBaseIntents.CheckServerStatusIntent when linked
                // For now, use placeholder
                let latency = Date().timeIntervalSince(startTime)

                let entry = ServerStatusEntry(
                    date: Date(),
                    isOnline: true,
                    latency: latency,
                    lastChecked: Date()
                )

                // Refresh every 15 minutes
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}

// MARK: - Widget View

struct ServerStatusWidgetView: View {
    var entry: ServerStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
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

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            statusIndicator
                .font(.title)
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
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ServerStatusWidget()
} timeline: {
    ServerStatusEntry.snapshot
}
