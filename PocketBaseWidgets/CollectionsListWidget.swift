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
            WidgetCollection(id: "4", name: "analytics_view", type: .view, recordCount: 0)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if entry.collections.isEmpty {
                emptyView
            } else {
                collectionsListView
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.blue)
            Text("Collections")
                .font(.headline)
            Spacer()
            Text("\(entry.collections.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            ForEach(entry.collections.prefix(6)) { collection in
                CollectionRowView(collection: collection)
            }

            if entry.collections.count > 6 {
                Text("+ \(entry.collections.count - 6) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
        .supportedFamilies([.systemLarge])
    }
}

#Preview(as: .systemLarge) {
    CollectionsListWidget()
} timeline: {
    CollectionsListEntry.snapshot
}
