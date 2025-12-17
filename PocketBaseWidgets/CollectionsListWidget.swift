//
//  CollectionsListWidget.swift
//  PocketBaseWidgets
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import WidgetKit
import SwiftUI

// MARK: - Collection Model

struct WidgetCollection: Identifiable {
    let id: String
    let name: String
    let type: WidgetCollectionType
    let recordCount: Int
}

enum WidgetCollectionType: String {
    case base
    case auth
    case view

    var icon: String {
        switch self {
        case .base: return "rectangle.stack"
        case .auth: return "person.badge.key"
        case .view: return "eye"
        }
    }

    var color: Color {
        switch self {
        case .base: return .blue
        case .auth: return .green
        case .view: return .purple
        }
    }
}

// MARK: - Timeline Entry

struct CollectionsListEntry: TimelineEntry {
    let date: Date
    let collections: [WidgetCollection]

    static var placeholder: CollectionsListEntry {
        CollectionsListEntry(date: Date(), collections: [
            WidgetCollection(id: "1", name: "users", type: .auth, recordCount: 156),
            WidgetCollection(id: "2", name: "posts", type: .base, recordCount: 1234),
            WidgetCollection(id: "3", name: "comments", type: .base, recordCount: 5678),
            WidgetCollection(id: "4", name: "analytics_view", type: .view, recordCount: 0),
            WidgetCollection(id: "5", name: "products", type: .base, recordCount: 892),
            WidgetCollection(id: "6", name: "orders", type: .base, recordCount: 2341),
            WidgetCollection(id: "7", name: "admins", type: .auth, recordCount: 3),
            WidgetCollection(id: "8", name: "categories", type: .base, recordCount: 24)
        ])
    }

    static var snapshot: CollectionsListEntry {
        placeholder
    }
}

// MARK: - Timeline Provider

struct CollectionsListProvider: TimelineProvider {
    func placeholder(in context: Context) -> CollectionsListEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CollectionsListEntry) -> Void) {
        completion(.snapshot)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CollectionsListEntry>) -> Void) {
        Task {
            // TODO: Use PocketBaseIntents.GetCollectionsIntent when linked
            let entry = CollectionsListEntry(date: Date(), collections: [])

            // Refresh every hour
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct CollectionsListWidgetView: View {
    var entry: CollectionsListEntry

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
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
                .widgetAccentable()

            Text("\(entry.collections.count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .widgetAccentable()

            Text(entry.collections.count == 1 ? "collection" : "collections")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !entry.collections.isEmpty {
                HStack(spacing: 4) {
                    let authCount = entry.collections.filter { $0.type == .auth }.count
                    if authCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.badge.key")
                                .font(.caption2)
                                .widgetAccentable()
                            Text("\(authCount)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                    }

                    let baseCount = entry.collections.filter { $0.type == .base }.count
                    if baseCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "rectangle.stack")
                                .font(.caption2)
                                .widgetAccentable()
                            Text("\(baseCount)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .foregroundStyle(.blue)
                    .widgetAccentable()
                Text("Collections")
                    .font(.headline)
                Spacer()
                Text("\(entry.collections.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
            }

            if entry.collections.isEmpty {
                HStack {
                    Spacer()
                    Text("No collections")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(entry.collections.prefix(4)) { collection in
                        VStack(spacing: 4) {
                            Image(systemName: collection.type.icon)
                                .font(.title3)
                                .foregroundStyle(collection.type.color)
                                .widgetAccentable()
                            Text(collection.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Text(formatCount(collection.recordCount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
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

            if entry.collections.isEmpty {
                emptyView
            } else {
                collectionsListView
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
                Text("\(entry.collections.count)")
                    .font(.title2.bold())
                    .widgetAccentable()
                Image(systemName: "rectangle.stack")
                    .font(.caption2)
                    .widgetAccentable()
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading) {
                Text("\(entry.collections.count)")
                    .font(.title.bold())
                    .widgetAccentable()
                Text(entry.collections.count == 1 ? "collection" : "collections")
                    .font(.caption2)
            }

            Divider()

            if let topCollection = entry.collections.first {
                VStack(alignment: .leading) {
                    Image(systemName: topCollection.type.icon)
                        .foregroundStyle(topCollection.type.color)
                        .widgetAccentable()
                    Text(topCollection.name)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } else {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: "rectangle.stack")
                .widgetAccentable()
            Text("\(entry.collections.count) \(entry.collections.count == 1 ? "collection" : "collections")")
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.blue)
                .widgetAccentable()
            Text("Collections")
                .font(.headline)
            Spacer()
            Text("\(entry.collections.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .widgetAccentable()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No collections")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Create one in the app")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var collectionsListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.collections.prefix(8)) { collection in
                CollectionRowView(collection: collection)
            }

            if entry.collections.count > 8 {
                Text("+ \(entry.collections.count - 8) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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

struct CollectionRowView: View {
    let collection: WidgetCollection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: collection.type.icon)
                .font(.caption)
                .foregroundStyle(collection.type.color)
                .frame(width: 16)
                .widgetAccentable()

            Text(collection.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text(formatCount(collection.recordCount))
                .font(.caption2)
                .foregroundStyle(.secondary)
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

// MARK: - Widget Definition

struct CollectionsListWidget: Widget {
    let kind: String = "CollectionsListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CollectionsListProvider()) { entry in
            CollectionsListWidgetView(entry: entry)
        }
        .configurationDisplayName("Collections")
        .description("View your PocketBase collections")
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
    CollectionsListWidget()
} timeline: {
    CollectionsListEntry.snapshot
}

#Preview(as: .systemMedium) {
    CollectionsListWidget()
} timeline: {
    CollectionsListEntry.snapshot
}

#Preview(as: .systemLarge) {
    CollectionsListWidget()
} timeline: {
    CollectionsListEntry.snapshot
}
