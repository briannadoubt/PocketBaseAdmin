//
//  RequestVolumeWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import Charts

/// Request volume widget showing a line chart of request counts over time
struct RequestVolumeWidgetView: View {
    let data: RequestVolumeData

    /// Selected date for interactive chart (iOS 17+)
    @State private var selectedDate: Date?

    /// Find the data point closest to the selected date
    private var selectedPoint: RequestVolumeData.DataPoint? {
        guard let selectedDate else { return nil }
        return data.dataPoints.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    /// Average request count for reference line
    private var averageCount: Double {
        guard !data.dataPoints.isEmpty else { return 0 }
        return Double(data.dataPoints.reduce(0) { $0 + $1.count }) / Double(data.dataPoints.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Request Volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let selected = selectedPoint {
                        // Show selected value
                        Text("\(selected.count.formatted())")
                            .font(.title2.bold())
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                    } else {
                        Text("\(data.totalRequests.formatted())")
                            .font(.title2.bold())
                    }
                }
                Spacer()

                if let selected = selectedPoint {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(selected.date, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("selected")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .animation(.smooth, value: selectedDate)

            // Chart
            if data.dataPoints.isEmpty {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.line.flattrend.xyaxis")
                } description: {
                    Text("No request data available")
                }
                .frame(height: 100)
            } else {
                Chart {
                    // Data line and area
                    ForEach(data.dataPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Requests", point.count)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Requests", point.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Average reference line
                    if averageCount > 0 {
                        RuleMark(y: .value("Average", averageCount))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Selection indicator
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(.blue.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1))

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Requests", selected.count)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(100)

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Requests", selected.count)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(40)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 100)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RequestVolumeWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
