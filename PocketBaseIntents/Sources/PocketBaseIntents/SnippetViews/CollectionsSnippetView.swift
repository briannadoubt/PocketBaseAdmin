//
//  CollectionsSnippetView.swift
//  PocketBaseIntents
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI

/// Visual snippet view for collections shown in Siri/Shortcuts
public struct CollectionsSnippetView: View {
    public let collections: [CollectionEntity]

    public init(collections: [CollectionEntity]) {
        self.collections = collections
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .foregroundStyle(.blue)
                Text("\(collections.count) Collections")
                    .font(.headline)
                Spacer()
            }

            if collections.isEmpty {
                Text("No collections found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collections.prefix(5), id: \.id) { collection in
                    HStack(spacing: 8) {
                        Image(systemName: iconForType(collection.type))
                            .font(.caption)
                            .foregroundStyle(colorForType(collection.type))
                            .frame(width: 16)

                        Text(collection.name)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text("\(collection.recordCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if collections.count > 5 {
                    Text("+ \(collections.count - 5) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func iconForType(_ type: CollectionType) -> String {
        switch type {
        case .base: return "rectangle.stack"
        case .auth: return "person.badge.key"
        case .view: return "eye"
        }
    }

    private func colorForType(_ type: CollectionType) -> Color {
        switch type {
        case .base: return .blue
        case .auth: return .green
        case .view: return .purple
        }
    }
}

/// Stats overview view for widgets
public struct StatsOverviewView: View {
    public let collectionsCount: Int
    public let recordsCount: Int
    public let errorsCount: Int

    public init(collectionsCount: Int, recordsCount: Int, errorsCount: Int) {
        self.collectionsCount = collectionsCount
        self.recordsCount = recordsCount
        self.errorsCount = errorsCount
    }

    public var body: some View {
        HStack(spacing: 16) {
            StatItem(value: collectionsCount, label: "Collections", icon: "rectangle.stack")
            StatItem(value: recordsCount, label: "Records", icon: "doc.text")
            StatItem(value: errorsCount, label: "Errors (24h)", icon: "exclamationmark.circle", color: errorsCount > 0 ? .red : .green)
        }
        .padding()
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
