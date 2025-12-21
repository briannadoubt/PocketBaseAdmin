//
//  ErrorRateWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import Charts

/// Error rate widget showing error trends over time
struct ErrorRateWidgetView: View {
    let data: ErrorRateData

    /// Error threshold for warning line (configurable)
    var errorThreshold: Int = 5

    /// Selected date for interactive chart
    @State private var selectedDate: Date?

    /// Find the data point closest to the selected date
    private var selectedPoint: ErrorRateData.DataPoint? {
        guard let selectedDate else { return nil }
        return data.dataPoints.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    /// Max error count for chart scaling
    private var maxErrors: Int {
        max(data.dataPoints.map(\.count).max() ?? 0, errorThreshold + 2)
    }

    private var errorColor: Color {
        if data.totalErrors == 0 {
            return .green
        } else if data.errorRate < 1 {
            return .yellow
        } else if data.errorRate < 5 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Error Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let selected = selectedPoint {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(selected.count)")
                                .font(.title2.bold())
                                .foregroundStyle(selected.count > errorThreshold ? .red : errorColor)
                                .contentTransition(.numericText())
                            Text("at \(selected.date, format: .dateTime.hour().minute())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(data.totalErrors)")
                                .font(.title2.bold())
                            Text("errors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", data.errorRate))
                        .font(.headline)
                        .foregroundStyle(errorColor)
                    Text("of requests")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .animation(.smooth, value: selectedDate)

            // Chart
            if data.dataPoints.isEmpty {
                ContentUnavailableView {
                    Label("No Data", systemImage: "chart.line.flattrend.xyaxis")
                } description: {
                    Text("No error data available")
                }
                .frame(height: 100)
            } else {
                Chart {
                    // Error threshold line
                    RuleMark(y: .value("Threshold", errorThreshold))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("threshold")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.7))
                        }

                    // Data points
                    ForEach(data.dataPoints) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Errors", point.count)
                        )
                        .foregroundStyle(errorColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Errors", point.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [errorColor.opacity(0.3), errorColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)

                        // Show points only for non-zero values
                        if point.count > 0 {
                            PointMark(
                                x: .value("Time", point.date),
                                y: .value("Errors", point.count)
                            )
                            .foregroundStyle(point.count > errorThreshold ? .red : errorColor)
                            .symbolSize(point.count > errorThreshold ? 50 : 30)
                        }
                    }

                    // Selection indicator
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(errorColor.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1))

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Errors", selected.count)
                        )
                        .foregroundStyle(selected.count > errorThreshold ? .red : errorColor)
                        .symbolSize(100)

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Errors", selected.count)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(40)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: 0...maxErrors)
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
    ErrorRateWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
