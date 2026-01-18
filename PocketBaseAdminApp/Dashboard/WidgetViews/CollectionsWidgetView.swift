//
//  CollectionsWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import Charts

/// Collections widget showing record counts per collection with a bar chart
struct CollectionsWidgetView: View {
    let data: CollectionsData

    /// Top 6 collections by record count (excluding system collections for clarity)
    private var topCollections: [CollectionsData.CollectionCount] {
        data.collections
            .filter { !$0.isSystem }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(data.collections.count)")
                            .font(.title2.bold())
                        Text("total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(data.totalRecords.formatted())
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Text("records")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Bar chart
            if topCollections.isEmpty {
                ContentUnavailableView {
                    Label("No Collections", systemImage: "rectangle.stack")
                } description: {
                    Text("Create your first collection")
                }
                .frame(height: 100)
            } else {
                Chart(topCollections) { collection in
                    BarMark(
                        x: .value("Count", collection.count),
                        y: .value("Collection", collection.name)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text(collection.count.formatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                Text(name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: max(CGFloat(topCollections.count) * 28, 100))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CollectionsWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
