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
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Actions")
                    .font(.caption.bold())
                Spacer()
            }

            HStack(spacing: 8) {
                Button(intent: CreateBackupWidgetIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "archivebox")
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .widgetAccentable()
                        Text("Backup")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                Button(intent: RefreshStatusWidgetIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .widgetAccentable()
                        Text("Refresh")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
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

    private var largeView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text("Quick Actions")
                    .font(.title2.bold())
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                LargeActionButton(
                    title: "Create Backup",
                    subtitle: "Save database",
                    icon: "archivebox.fill",
                    color: .blue,
                    intent: CreateBackupWidgetIntent()
                )

                LargeActionButton(
                    title: "Refresh Status",
                    subtitle: "Update widgets",
                    icon: "arrow.clockwise",
                    color: .green,
                    intent: RefreshStatusWidgetIntent()
                )

                LargeActionButton(
                    title: "View Logs",
                    subtitle: "Open log viewer",
                    icon: "doc.text.fill",
                    color: .orange,
                    intent: ViewLogsWidgetIntent()
                )

                LargeActionButton(
                    title: "Open Admin",
                    subtitle: "Manage server",
                    icon: "server.rack",
                    color: .purple,
                    intent: ViewLogsWidgetIntent()
                )
            }

            Spacer(minLength: 0)

            HStack {
                Text("Tap an action to execute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .widgetAccentable()

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

struct LargeActionButton<I: AppIntent>: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let intent: I

    var body: some View {
        Button(intent: intent) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .widgetAccentable()

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
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
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry.snapshot
}

#Preview(as: .systemSmall) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry.snapshot
}

#Preview(as: .systemLarge) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry.snapshot
}
