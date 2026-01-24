//
//  ErrorCountWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI
import PocketBaseIntents

// MARK: - Timeline Entry

struct ErrorCountEntry: TimelineEntry {
    let date: Date
    let errorCount: Int
    let warningCount: Int
    let period: String

    static var placeholder: ErrorCountEntry {
        ErrorCountEntry(date: Date(), errorCount: 0, warningCount: 2, period: "24h")
    }

    static var snapshot: ErrorCountEntry {
        ErrorCountEntry(date: Date(), errorCount: 3, warningCount: 7, period: "24h")
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
        Task { @MainActor in
            async let errorCount = IntentHelpers.fetchErrorCount()
            async let warningCount = IntentHelpers.fetchWarningCount()

            let entry = ErrorCountEntry(
                date: Date(),
                errorCount: await errorCount,
                warningCount: await warningCount,
                period: "24h"
            )

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
        VStack(spacing: 4) {
            Text("\(entry.errorCount)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(entry.color)
                .widgetAccentable()

            Text(entry.errorCount == 1 ? "error" : "errors")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("last \(entry.period)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(entry.errorCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.color)
                    .widgetAccentable()
                Text("errors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 4) {
                Text("\(entry.warningCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .widgetAccentable()
                Text("warnings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(entry.color)
                    .widgetAccentable()
                Spacer()
                Text("last \(entry.period)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(entry.color)
                    .widgetAccentable()
                Text("Error Summary")
                    .font(.headline)
                Spacer()
                Text("last \(entry.period)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                ErrorStatBox(count: entry.errorCount, label: "Errors", color: .red, icon: "xmark.circle")
                ErrorStatBox(count: entry.warningCount, label: "Warnings", color: .orange, icon: "exclamationmark.triangle")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline.bold())

                HStack {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 12, height: 12)
                        .widgetAccentable()
                    Text(statusMessage)
                        .font(.subheadline)
                        .widgetAccentable()
                    Spacer()
                }
            }

            Spacer(minLength: 0)

            Text("Tap to view detailed logs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var statusMessage: String {
        switch entry.errorCount {
        case 0: return "All systems operational"
        case 1...5: return "Some issues detected"
        default: return "Multiple errors - attention needed"
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.errorCount)")
                    .font(.title2.bold())
                    .foregroundStyle(entry.color)
                    .widgetAccentable()
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Text("\(entry.errorCount)")
                .font(.title.bold())
                .foregroundStyle(entry.color)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.errorCount == 1 ? "Error" : "Errors")
                    .font(.headline)
                Text("last \(entry.period)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .widgetAccentable()
            Text("\(entry.errorCount) errors")
        }
    }
}

struct ErrorStatBox: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .widgetAccentable()

            Text("\(count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
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
    ErrorCountWidget()
} timeline: {
    ErrorCountEntry.snapshot
    ErrorCountEntry(date: Date(), errorCount: 0, warningCount: 0, period: "24h")
    ErrorCountEntry(date: Date(), errorCount: 12, warningCount: 5, period: "24h")
}
