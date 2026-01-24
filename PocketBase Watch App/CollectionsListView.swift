//
//  CollectionsListView.swift
//  PocketBase Watch App
//
//  Created by Claude Code on behalf of Brianna Zamora
//

import SwiftUI
import WatchKit
import PocketBaseIntents

struct WatchCollection: Identifiable {
    let id: String
    let name: String
    let type: WatchCollectionType
    let recordCount: Int

    init(id: String, name: String, type: WatchCollectionType, recordCount: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.recordCount = recordCount
    }

    init(from simpleCollection: SimpleCollection) {
        self.id = simpleCollection.id
        self.name = simpleCollection.name
        self.type = WatchCollectionType(from: simpleCollection.type)
        self.recordCount = simpleCollection.recordCount
    }
}

enum WatchCollectionType: String {
    case base
    case auth
    case view

    init(from simpleType: SimpleCollectionType) {
        switch simpleType {
        case .base: self = .base
        case .auth: self = .auth
        case .view: self = .view
        }
    }

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

    @MainActor
    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        WKInterfaceDevice.current().play(.start)

        let simpleCollections = await IntentHelpers.fetchCollections()
        collections = simpleCollections.map { WatchCollection(from: $0) }

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
