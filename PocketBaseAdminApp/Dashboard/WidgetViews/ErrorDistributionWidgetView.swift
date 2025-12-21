//
//  ErrorDistributionWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import Charts

/// Error distribution widget showing a pie/donut chart of error categories
struct ErrorDistributionWidgetView: View {
    let data: ErrorDistributionData

    /// Selected category for interactive chart
    @State private var selectedCategory: ErrorDistributionData.ErrorCategory?

    /// Angle for selected category (for selection detection)
    @State private var selectedAngle: Double?

    /// Find the category at the given angle
    private func category(for angle: Double) -> ErrorDistributionData.ErrorCategory? {
        guard data.totalErrors > 0 else { return nil }

        var cumulativeAngle = 0.0
        for category in data.categories {
            let proportion = Double(category.count) / Double(data.totalErrors)
            let categoryAngle = proportion * 360.0
            if angle >= cumulativeAngle && angle < cumulativeAngle + categoryAngle {
                return category
            }
            cumulativeAngle += categoryAngle
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Error Distribution")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let selected = selectedCategory {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(selected.count)")
                                .font(.title2.bold())
                                .foregroundStyle(selected.color)
                                .contentTransition(.numericText())
                            Text(selected.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(data.totalErrors)")
                                .font(.title2.bold())
                            Text("total errors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()

                Image(systemName: "chart.pie")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .animation(.smooth, value: selectedCategory?.id)

            // Pie Chart
            if data.categories.isEmpty {
                ContentUnavailableView {
                    Label("No Errors", systemImage: "checkmark.circle")
                } description: {
                    Text("No errors recorded")
                }
                .frame(height: 120)
            } else {
                HStack(spacing: 16) {
                    // Donut chart
                    Chart(data.categories) { category in
                        SectorMark(
                            angle: .value("Count", category.count),
                            innerRadius: .ratio(0.5),
                            outerRadius: selectedCategory?.id == category.id ? .ratio(1.0) : .ratio(0.9),
                            angularInset: 1.5
                        )
                        .foregroundStyle(category.color)
                        .cornerRadius(4)
                        .opacity(selectedCategory == nil || selectedCategory?.id == category.id ? 1.0 : 0.5)
                    }
                    .chartAngleSelection(value: $selectedAngle)
                    .chartBackground { _ in
                        // Center label
                        if let selected = selectedCategory {
                            VStack(spacing: 0) {
                                Text("\(selected.count)")
                                    .font(.title3.bold())
                                    .foregroundStyle(selected.color)
                                    .contentTransition(.numericText())
                                Text(selected.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            VStack(spacing: 0) {
                                Text("\(data.totalErrors)")
                                    .font(.title3.bold())
                                Text("errors")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 100, height: 100)
                    .animation(.smooth, value: selectedCategory?.id)

                    // Legend
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(data.categories.prefix(4)) { category in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundStyle(selectedCategory == nil || selectedCategory?.id == category.id ? .primary : .secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(category.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.smooth) {
                                    if selectedCategory?.id == category.id {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedAngle) { _, newAngle in
            if let angle = newAngle {
                withAnimation(.smooth) {
                    selectedCategory = category(for: angle)
                }
            }
        }
    }
}

#Preview {
    ErrorDistributionWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
