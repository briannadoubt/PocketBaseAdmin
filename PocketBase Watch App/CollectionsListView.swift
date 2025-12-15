//
//  CollectionsListView.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import WatchKit

struct WatchCollection: Identifiable {
    let id: String
    let name: String
    let type: WatchCollectionType
    let recordCount: Int
}

enum WatchCollectionType: String {
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

struct CollectionsListView: View {
    @State private var collections: [WatchCollection] = []
    @State private var isLoading = false

    private var totalRecords: Int {
        collections.reduce(0) { $0 + $1.recordCount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Summary
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(collections.count)")
                            .font(.title2.bold())
                        Text("Collections")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(formatCount(totalRecords))
                            .font(.title2.bold())
                        Text("Total Records")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                )
                .padding(.horizontal)

                Divider()

                // Collections list
                if isLoading {
                    ProgressView()
                        .padding()
                } else if collections.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No collections")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ForEach(collections) { collection in
                        CollectionRow(collection: collection)
                    }
                }
            }
        }
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        WKInterfaceDevice.current().play(.start)

        // TODO: Use GetCollectionsIntent
        // For now, use sample data
        try? await Task.sleep(for: .milliseconds(500))

        collections = [
            WatchCollection(id: "1", name: "users", type: .auth, recordCount: 156),
            WatchCollection(id: "2", name: "posts", type: .base, recordCount: 1234),
            WatchCollection(id: "3", name: "comments", type: .base, recordCount: 5678),
            WatchCollection(id: "4", name: "categories", type: .base, recordCount: 12),
            WatchCollection(id: "5", name: "analytics", type: .view, recordCount: 0)
        ]

        WKInterfaceDevice.current().play(.success)
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

struct CollectionRow: View {
    let collection: WatchCollection

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: collection.type.icon)
                .font(.caption)
                .foregroundStyle(collection.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.caption)
                    .lineLimit(1)

                Text(collection.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(collection.recordCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        CollectionsListView()
    }
}
