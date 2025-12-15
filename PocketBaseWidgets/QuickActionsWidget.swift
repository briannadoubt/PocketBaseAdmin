//
//  QuickActionsWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct QuickActionsEntry: TimelineEntry {
    let date: Date
    let isOnline: Bool

    static var placeholder: QuickActionsEntry {
        QuickActionsEntry(date: Date(), isOnline: true)
    }

    static var snapshot: QuickActionsEntry {
        QuickActionsEntry(date: Date(), isOnline: true)
    }
}

// MARK: - Timeline Provider

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = QuickActionsEntry(date: Date(), isOnline: true)
        // Actions widget doesn't need frequent updates
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - App Intents for Widget Buttons

struct CreateBackupWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Backup"
    static let description = IntentDescription("Create a new PocketBase backup from the widget")

    func perform() async throws -> some IntentResult & OpensIntent {
        // This will open the app and trigger the backup
        // TODO: Wire to CreateBackupIntent from PocketBaseIntents
        return .result(opensIntent: OpenURLIntent())
    }
}

struct RefreshStatusWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Status"
    static let description = IntentDescription("Refresh server status")

    func perform() async throws -> some IntentResult {
        // Trigger widget refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "ServerStatusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "StatsWidget")
        return .result()
    }
}

struct ViewLogsWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "View Logs"
    static let description = IntentDescription("Open the app to view logs")

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent())
    }
}

// MARK: - Widget View

struct QuickActionsWidgetView: View {
    var entry: QuickActionsEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                ActionButton(
                    title: "Backup",
                    icon: "archivebox",
                    color: .blue,
                    intent: CreateBackupWidgetIntent()
                )

                ActionButton(
                    title: "Refresh",
                    icon: "arrow.clockwise",
                    color: .green,
                    intent: RefreshStatusWidgetIntent()
                )

                ActionButton(
                    title: "Logs",
                    icon: "doc.text",
                    color: .orange,
                    intent: ViewLogsWidgetIntent()
                )
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ActionButton<I: AppIntent>: View {
    let title: String
    let icon: String
    let color: Color
    let intent: I

    var body: some View {
        Button(intent: intent) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Definition

struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly backup, refresh, or view logs")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry.snapshot
}
