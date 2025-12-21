//
//  LatencyWidgetView.swift
//  PocketBaseAdminApp
//
//  Created by Claude Code on behalf of Brianna Zamora
//
//  Shared widget view - used by both in-app dashboard and WidgetKit home screen widgets
//

import SwiftUI
import Charts

/// Latency widget with a gauge and historical line chart
struct LatencyWidgetView: View {
    let data: LatencyData

    /// Selected date for interactive chart
    @State private var selectedDate: Date?

    /// Find the data point closest to the selected date
    private var selectedPoint: LatencyData.DataPoint? {
        guard let selectedDate else { return nil }
        return data.history.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    /// Color based on latency value
    private func latencyColor(for ms: Double) -> Color {
        switch ms {
        case 0..<50: .green
        case 50..<100: .blue
        case 100..<200: .orange
        default: .red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header with gauge and current value
            HStack(alignment: .center, spacing: 16) {
                // Compact gauge
                Gauge(value: min(data.currentMs, 200), in: 0...200) {
                    EmptyView()
                } currentValueLabel: {
                    if let selected = selectedPoint {
                        Text("\(Int(selected.latencyMs))")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(latencyColor(for: selected.latencyMs))
                            .contentTransition(.numericText())
                    } else {
                        Text("\(Int(data.currentMs))")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                }
                .gaugeStyle(.accessoryCircular)
                .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                .scaleEffect(1.2)
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Latency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let selected = selectedPoint {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(selected.latencyMs))ms")
                                .font(.title2.bold())
                                .foregroundStyle(latencyColor(for: selected.latencyMs))
                                .contentTransition(.numericText())
                            Text(selected.date, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(data.currentMs))ms")
                                .font(.title2.bold())
                                .foregroundStyle(latencyColor(for: data.currentMs))
                            Text(data.status.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(data.status.color)
                    .frame(width: 10, height: 10)
            }
            .animation(.smooth, value: selectedDate)

            // Historical line chart
            if !data.history.isEmpty {
                Chart {
                    // Average reference line
                    RuleMark(y: .value("Average", data.averageMs))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                    // Data line
                    ForEach(data.history) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Latency", point.latencyMs)
                        )
                        .foregroundStyle(latencyColor(for: data.currentMs))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Latency", point.latencyMs)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [latencyColor(for: data.currentMs).opacity(0.3), latencyColor(for: data.currentMs).opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Selection indicator
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(latencyColor(for: selected.latencyMs).opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1))

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Latency", selected.latencyMs)
                        )
                        .foregroundStyle(latencyColor(for: selected.latencyMs))
                        .symbolSize(100)

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Latency", selected.latencyMs)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(40)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: 0...(max(data.maxMs, data.history.map(\.latencyMs).max() ?? 100) * 1.1))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let ms = value.as(Double.self) {
                                Text("\(Int(ms))")
                            }
                        }
                    }
                }
                .frame(height: 80)
            }

            // Stats row
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Avg")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(data.averageMs))ms")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(data.minMs))ms")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }

                VStack(spacing: 2) {
                    Text("Max")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(data.maxMs))ms")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LatencyWidgetView(data: .placeholder)
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
